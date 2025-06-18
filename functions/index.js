// functions/index.js
const {onRequest} = require("firebase-functions/v2/https"); // Corrected import
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();
const db = admin.firestore();

// This line will fetch the token from the environment.
// When deployed, Google Secret Manager (via the {secrets: ...} config)
// provides this value.
const REVENUECAT_BEARER_TOKEN = process.env.REVENUECAT_BEARER_TOKEN;

exports.revenueCatWebhook = onRequest(
    {secrets: ["REVENUECAT_BEARER_TOKEN"]}, // Load this secret from Secret Manager
    async (req, res) => {
    // (indent 2 spaces from here)
      if (!REVENUECAT_BEARER_TOKEN) {
        logger.error(
            "CRITICAL: Bearer token missing or not loaded\n" +
            "(env vars/Secret Manager).",
        );
        res.status(500).send(
            "Webhook authentication not configured properly.",
        );
        return;
      }

      // 1. Verify Bearer Token
      const authHeader = req.headers.authorization;

      if (!authHeader) {
        logger.warn("Missing Authorization header.");
        res.status(401).send("Unauthorized: Missing Authorization header.");
        return;
      }

      const [authType, receivedToken] = authHeader.split(" ");

      if (authType !== "Bearer" || !receivedToken) {
        logger.warn("Invalid Authorization header format.");
        res.status(401).send(
            "Unauthorized: Invalid Authorization header format.",
        );
        return;
      }

      // Compare the received token with the one loaded from Secret Manager
      if (receivedToken !== REVENUECAT_BEARER_TOKEN) {
        logger.warn("Invalid Bearer token received.");
        res.status(401).send("Unauthorized: Invalid token."); // max-len ok (78)
        return;
      }

      // Authentication successful, now process the event
      try {
      // (indent 4 spaces from here)
        const body = req.body;
        const payload = body.event ? body.event : body;
        const eventType = payload.type;
        const appUserId = payload.app_user_id;
        const productId = payload.product_id;
        const eventId = payload.id; // Unique ID for idempotency

        logger.info("Received authenticated RevenueCat webhook", {
          eventId,
          eventType,
          appUserId,
          productId,
          payloadTimestamp: payload.event_timestamp_ms,
        });

        if (!appUserId) {
          logger.warn("No appUserId provided in webhook payload.");
          res.status(400).send("Missing app_user_id.");
          return;
        }

        if (!eventId) {
          logger.warn(
              "No event ID (payload.id) provided. " +
              "Cannot ensure idempotency.",
          );
          res.status(400).send("Missing event ID.");
          return;
        }

        // 2. Idempotency Check
        const eventRef = db.collection("processedRevenueCatEvents").doc(eventId);
        const eventDoc = await eventRef.get();

        if (eventDoc.exists) {
          logger.info(`Event ${eventId} already processed. Skipping.`);
          res.status(200).send("Event already processed.");
          return;
        }

        // Process specific event types
        // (indent 6 spaces from here)
        if (eventType === "INITIAL_PURCHASE" || eventType === "RENEWAL") {
          await grantTokensToUser(appUserId, productId, eventType);
        } else if (eventType === "CANCELLATION" || eventType === "EXPIRATION") {
          await removeTokensFromUser(appUserId, eventType);
        } else if (eventType === "TEST") {
          logger.info(
              "TEST event: Auth OK.",
          );
        } else if (eventType === "TRANSFER") {
          logger.info(
              `TRANSFER event received for user ${appUserId}. ` +
            "Manual review might be needed or define specific logic.",
          );
        } else {
          logger.info(
              `Unhandled event type: ${eventType} for user ${appUserId}. ` +
            "Acknowledging.",
          );
        }

        // Mark event as processed
        await eventRef.set({
          appUserId: appUserId,
          eventType: eventType,
          productId: productId || null,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        res.status(200).send("Webhook processed successfully.");
      } catch (error) {
        logger.error("Error processing RevenueCat webhook payload:", error, {
          eventId: (req.body && req.body.event && req.body.event.id) ?
            req.body.event.id :
            (req.body ? req.body.id : undefined),
        });
        res.status(500).send(
            "Internal server error while processing payload.",
        );
      }
    },
);

/**
 * Grants tokens to a user and updates their subscription status in Firestore.
 * @param {string} firebaseUid The Firebase UID of the user.
 * @param {string} productId The RevenueCat product ID of the subscription.
 * @param {string} eventType The type of RevenueCat event
 * (e.g., INITIAL_PURCHASE).
 * @return {Promise<void>} A promise that resolves when the user is updated.
 */
async function grantTokensToUser(firebaseUid, productId, eventType) {
  const userRef = db.collection("users").doc(firebaseUid);
  let tokensToGrant = 0;

  if (productId === "bugid_weekly_299") {
    tokensToGrant = 200;
  } else if (productId === "bugid_yearly_6999") {
    tokensToGrant = 4000;
  } else {
    logger.warn(
        `Unknown product ID "${productId}" for token grant for user ` +
        `${firebaseUid}. Granting 0 tokens.`,
    );
  }

  if (tokensToGrant > 0 || eventType === "INITIAL_PURCHASE") {
    logger.info(
        `Granting ${tokensToGrant} tokens to user ${firebaseUid} for ` +
        `product ${productId} due to ${eventType}.`,
    );
    try {
      await userRef.set({
        tokens: admin.firestore.FieldValue.increment(tokensToGrant),
        subscriptionActive: true,
        subscriptionProductId: productId,
        lastSubscriptionEvent: eventType,
        lastGrantAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.info(
          `Successfully granted tokens and updated subscription for user ` +
          `${firebaseUid}.`,
      );
    } catch (error) {
      logger.error(
          `Failed to grant tokens for user ${firebaseUid}:`, error,
      );
      throw error;
    }
  } else {
    logger.info(
        `No tokens to grant for product ID "${productId}" for user ` +
        `${firebaseUid}, but ensuring subscription status is active for ` +
        `${eventType}.`,
    );
    try {
      await userRef.set({
        subscriptionActive: true,
        subscriptionProductId: productId,
        lastSubscriptionEvent: eventType,
        lastGrantAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.info(
          `Successfully updated subscription status for user ${firebaseUid} ` +
          "without token grant.",
      );
    } catch (error) {
      logger.error(
          `Failed to update subscription status for user ${firebaseUid}:`, error,
      );
      throw error;
    }
  }
}

/**
 * Sets a user's subscription to inactive and tokens to 0 in Firestore.
 * @param {string} firebaseUid The Firebase UID of the user.
 * @param {string} eventType The type of RevenueCat event
 * (e.g., CANCELLATION).
 * @return {Promise<void>} A promise that resolves when the user is updated.
 */
async function removeTokensFromUser(firebaseUid, eventType) {
  const userRef = db.collection("users").doc(firebaseUid);
  logger.info(
      `User ${firebaseUid} sub inactive for ${eventType}.\n` +
      `Tokens set to 0.`,
  );

  try {
    await userRef.set({
      tokens: 0,
      subscriptionActive: false,
      lastSubscriptionEvent: eventType,
      lastCancellationAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    logger.info(
        `Successfully updated subscription to inactive for user ` +
        `${firebaseUid}.`,
    );
  } catch (error) {
    logger.error(
        "Error setting user " + firebaseUid + " to inactive. " +
            "Event: " + eventType + ". Details follow:",
        error,
    );
    throw error;
  }
}
