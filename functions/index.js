// functions/index.js
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https"); // Corrected import
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
        logger.info("Full RevenueCat Webhook req.body:", req.body); // Log the entire request body
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
          originalAppUserId: payload.original_app_user_id, // Log the original_app_user_id
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
          const originalAppUserId = payload.original_app_user_id;
          if (originalAppUserId && originalAppUserId !== appUserId) {
            await transferSubscription(
                originalAppUserId,
                appUserId,
                eventType,
            );
          } else {
            logger.warn(
                "TRANSFER event received without a valid " +
                `original_app_user_id. New UID: ${appUserId}, Original ` +
                `UID: ${originalAppUserId || "not provided"}.`,
            );
          }
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
        isPremium: true, // <-- Add this line
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
        isPremium: true, // <-- Add this line (for cases like TEST events or initial setup if needed)
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
      isPremium: false, // <-- Add this line
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

/**
 * Transfers subscription status from an old user ID to a new one.
 * @param {string} fromUid The original Firebase UID.
 * @param {string} toUid The new Firebase UID.
 * @param {string} eventType The type of RevenueCat event ("TRANSFER").
 * @return {Promise<void>} A promise that resolves when the transfer is complete.
 */
async function transferSubscription(fromUid, toUid, eventType) {
  logger.info(`Transferring subscription from ${fromUid} to ${toUid}.`);
  const fromUserRef = db.collection("users").doc(fromUid);
  const toUserRef = db.collection("users").doc(toUid);

  try {
    // Use a transaction to ensure atomicity
    await db.runTransaction(async (transaction) => {
      const fromUserDoc = await transaction.get(fromUserRef);
      const toUserDoc = await transaction.get(toUserRef);

      if (!fromUserDoc.exists) {
        logger.warn(
            `Original user document ${fromUid} not found for transfer. ` +
            "This is expected if the anonymous user had no Firestore doc. " +
            "The new user's entitlements will be set by other events.",
        );
        return;
      }

      const fromUserData = fromUserDoc.data();
      const fromTokens = fromUserData.tokens || 0;
      const toTokens = (toUserDoc.exists && toUserDoc.data().tokens) ?
        toUserDoc.data().tokens : 0;

      // 1. Set/update subscription data on the new user document
      transaction.set(toUserRef, {
        isPremium: fromUserData.isPremium || false,
        subscriptionActive: fromUserData.subscriptionActive || false,
        subscriptionProductId: fromUserData.subscriptionProductId || null,
        lastSubscriptionEvent: eventType,
        lastGrantAt: admin.firestore.FieldValue.serverTimestamp(),
        tokens: fromTokens + toTokens, // Combine tokens
      }, {merge: true});

      // 2. Invalidate the old user's subscription data
      transaction.set(fromUserRef, {
        tokens: 0,
        isPremium: false,
        subscriptionActive: false,
        lastSubscriptionEvent: "TRANSFERRED_AWAY",
        lastCancellationAt: admin.firestore.FieldValue.serverTimestamp(),
        transferredTo: toUid, // Keep a record of the transfer
      }, {merge: true});
    });

    logger.info(`Successfully transferred subscription from ${fromUid} to ${toUid}.`);
  } catch (error) {
    logger.error(
        `Failed to transfer subscription from ${fromUid} to ${toUid}:`,
        error,
    );
    throw error;
  }
}

/**
 * Consumes one token from a user if they are not a premium subscriber.
 * This is a callable function, invoked from the client.
 * @param {object} data The data passed to the function (not used).
 * @param {object} context The context of the call, including auth information.
 * @return {Promise<{success: boolean, tokensRemaining: number | string}>}
 * A promise that resolves with the result of the token consumption.
 */
exports.consumeToken = onCall(async (request) => {
  // 1. Check for authentication
  if (!request.auth) {
    // Throwing an HttpsError so that the client gets the error details.
    throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  const firebaseUid = request.auth.uid;
  const userRef = db.collection("users").doc(firebaseUid);
  logger.info(`Token consumption request for user: ${firebaseUid}`);

  try {
    // Use a transaction to atomically read and update the token count.
    return await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new HttpsError(
            "not-found",
            "User document not found.",
        );
      }

      const userData = userDoc.data();

      // 2. Premium users have unlimited access, no token change.
      if (userData.isPremium === true || userData.subscriptionActive === true) {
        logger.info(
            `User ${firebaseUid} is premium. Allowing action without cost.`,
        );
        return {success: true, tokensRemaining: "unlimited"};
      }

      // 3. Check if the user has enough tokens.
      const currentTokens = userData.tokens || 0;
      if (currentTokens <= 0) {
        logger.warn(
            `User ${firebaseUid} has no tokens. Denying action.`,
        );
        throw new HttpsError(
            "failed-precondition",
            "You are out of tokens. Please subscribe for more.",
        );
      }

      // 4. Decrement the token count within the transaction.
      transaction.update(userRef, {
        tokens: admin.firestore.FieldValue.increment(-1),
      });

      const newTokens = currentTokens - 1;
      logger.info(
          `Successfully consumed token for ${firebaseUid}. ` +
          `Remaining: ${newTokens}.`,
      );

      return {success: true, tokensRemaining: newTokens};
    });
  } catch (error) {
    // Re-throw HttpsError to the client, log other errors for debugging.
    if (error.code && error.http) { // Duck-typing for HttpsError
      throw error;
    }
    logger.error(
        `Error consuming token for user ${firebaseUid}:`,
        error,
    );
    throw new HttpsError(
        "internal",
        "An internal error occurred while consuming token.",
    );
  }
});

