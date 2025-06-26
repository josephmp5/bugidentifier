import SwiftUI
import PhotosUI
import FirebaseFunctions

struct CameraGalleryView: View {
    // Image & Navigation State
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var navigateToResults = false

    // API & Loading State
    @State private var isIdentifying = false
    @State private var identificationResult: BugIdentificationResult?
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    // Token & Paywall State
    @EnvironmentObject private var userManager: UserManager
    @State private var showPaywall = false

    private var greeting: String {
        return "Identify a New Bug"
    }

    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 20) { // Adjusted main spacing
                    SerifText(greeting, size: 30, color: ThemeColors.primaryText)
                        .padding(.top, 30) // More top padding for title

                    Spacer()

                    if let inputImage = inputImage {
                        ImagePreview(image: inputImage, onClear: clearImage)
                    } else {
                        PlaceholderImageView()
                    }

                    Spacer()

                    ActionButtonsView(showingCamera: $showingCamera, selectedItem: $selectedItem)
                        .padding(.horizontal, 30)
                    
                    if inputImage != nil {
                        PrimaryButton(title: "Identify Bug", action: performIdentification)
                            .padding(.horizontal, 30) // Consistent horizontal padding
                            .padding(.top, 10) // Space between action buttons and identify button
                            .disabled(isIdentifying)
                    }
                    
                    Spacer().frame(height: 10) // Small spacer at bottom
                    
                    // Navigation is triggered by identificationResult being set
                    if let result = identificationResult {
                        NavigationLink(destination: ResultsView(result: result, imageUrl: inputImage)
                                            .navigationBarBackButtonHidden(true), // Optional: hide back button for custom transition feel
                                       isActive: $navigateToResults) {
                            EmptyView()
                        }
                        .transaction { transaction in
                            transaction.animation = .easeInOut(duration: 0.5) // Apply to the navigation push/pop
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ThemeColors.background.edgesIgnoringSafeArea(.all))
                .navigationBarHidden(true)
                .fullScreenCover(isPresented: $showingCamera) {
                    ImagePicker(sourceType: .camera, selectedImage: $inputImage)
                        .ignoresSafeArea()
                }
                .onChange(of: selectedItem, perform: loadImage)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .disabled(isIdentifying) // Disable UI while loading

            // Loading Overlay
            if isIdentifying {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all) // Slightly less opaque background
                AnalyzingBugView()
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Identification Failed"),
                message: Text(errorMessage ?? "An unknown error occurred. Please try again."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isModal: true)
                .interactiveDismissDisabled()
        }
    }

    private func clearImage() {
        inputImage = nil
        selectedItem = nil
        identificationResult = nil
    }

    private func loadImage(from newItem: PhotosPickerItem?) {
        Task {
            guard let newItem = newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
            if let newImage = UIImage(data: data) {
                inputImage = newImage
            }
        }
    }

    private func performIdentification() {
        // Show loading indicator immediately
        isIdentifying = true

        // Ensure we have image data to process
        guard let image = inputImage, let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Could not process the selected image."
            showErrorAlert = true
            isIdentifying = false
            return
        }

        // Ensure we have a user profile to check for access
        guard let user = userManager.user else {
            errorMessage = "Could not verify your user profile. Please check your connection and try again."
            showErrorAlert = true
            isIdentifying = false
            return
        }

        // If user is not premium and has no tokens, show the paywall
        if !user.hasAccess {
            showPaywall = true
            isIdentifying = false
            return
        }

        // The user has access, so consume a token (or use their premium status)
        userManager.consumeToken { result in
            // Since CameraGalleryView is a struct, 'weak self' is not needed and causes a compiler error.
            // 'self' is captured by value automatically.
            switch result {
            case .success:
                // Token was consumed successfully, now call the Gemini API
                GeminiAPIService.shared.identifyBug(imageData: imageData) { result in
                    DispatchQueue.main.async {
                        // Hide the loading indicator
                        self.isIdentifying = false

                        switch result {
                        case .success(let identificationResult):
                            // Set the result, which makes the NavigationLink available
                            self.identificationResult = identificationResult
                            HistoryManager.shared.add(imageData: imageData, bugName: identificationResult.name)
                            
                            // Delay navigation slightly to allow the view hierarchy to update
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.navigateToResults = true
                            }
                        case .failure(let error):
                            // Show an error if identification fails
                            self.errorMessage = error.localizedDescription
                            self.showErrorAlert = true
                        }
                    }
                }
            case .failure(let error):
                // This handles failures from the consumeToken function
                DispatchQueue.main.async {
                    self.isIdentifying = false
                    let nsError = error as NSError
                    if nsError.domain == FunctionsErrorDomain,
                       let code = FunctionsErrorCode(rawValue: nsError.code),
                       code == .failedPrecondition {
                        // This is a specific error for "out of tokens"
                        self.errorMessage = nsError.userInfo[FunctionsErrorDetailsKey] as? String ?? "You are out of tokens."
                        self.showPaywall = true
                    } else {
                        // Handle other errors
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - Subviews for CameraGalleryView

struct ImagePreview: View {
    let image: UIImage
    var onClear: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 350)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: ThemeColors.primaryText.opacity(0.15), radius: 8, y: 4) // Softer shadow
                .padding(.horizontal, 30)

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(ThemeColors.background, ThemeColors.primaryText.opacity(0.7))
            }
            .padding(10) // Adjusted padding for tap area
        }
    }
}

struct PlaceholderImageView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "photo.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(ThemeColors.accent.opacity(0.4))
            Text("Tap to Select an Image")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(ThemeColors.primaryText.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .padding(.horizontal, 30)
    }
}

struct ActionButtonsView: View {
    @Binding var showingCamera: Bool
    @Binding var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 15) {
            ActionButton(iconName: "camera.fill", title: "Take Photo") {
                showingCamera = true
            }

            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ActionButtonContent(iconName: "photo.fill.on.rectangle.fill", title: "Choose from Gallery")
            }
        }
        // Horizontal padding moved to call site in CameraGalleryView's main VStack
    }
}

struct ActionButton: View {
    let iconName: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionButtonContent(iconName: iconName, title: title)
        }
    }
}

struct ActionButtonContent: View {
    let iconName: String
    let title: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ThemeColors.accent)
                .frame(width: 25) // Align icons
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ThemeColors.primaryText)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 65)
        .background(ThemeColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: ThemeColors.primaryText.opacity(0.08), radius: 5, y: 2)
    }
}

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundColor(ThemeColors.background)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(ThemeColors.primaryText)
                .cornerRadius(12)
                .shadow(color: ThemeColors.primaryText.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// ImagePicker remains the same
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct CameraGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        CameraGalleryView()
    }
}

