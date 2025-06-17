import SwiftUI
import PhotosUI

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

    private var greeting: String {
        return "Identify a New Bug"
    }

    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 25) {
                    Text(greeting)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.themeText)
                        .padding(.top, 20)

                    Spacer()

                    if let inputImage = inputImage {
                        ImagePreview(image: inputImage, onClear: clearImage)
                    } else {
                        PlaceholderImageView()
                    }

                    Spacer()

                    ActionButtonsView(showingCamera: $showingCamera, selectedItem: $selectedItem)
                    
                    if inputImage != nil {
                        PrimaryButton(title: "Identify Bug", action: performIdentification)
                            .padding(.horizontal, 40)
                            .disabled(isIdentifying)
                    }
                    
                    Spacer().frame(height: 20)
                    
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
                .background(Color.themeBackground.edgesIgnoringSafeArea(.all))
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
        guard let image = inputImage else { return }

        Task {
            isIdentifying = true
            do {
                let result = try await GeminiAPIService.shared.identifyBug(from: image)
                
                // Save to history on success
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    HistoryManager.shared.add(imageData: imageData, bugName: result.name)
                }
                
                // Set result and trigger navigation
                DispatchQueue.main.async {
                    self.identificationResult = result
                    self.navigateToResults = true
                }

            } catch {
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
            isIdentifying = false
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
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                .padding(.horizontal, 30)

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(8)
            .offset(x: -25, y: 5) // Adjust offset to be on the image corner
        }
    }
}

struct PlaceholderImageView: View {
    var body: some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .foregroundColor(Color.themeSecondaryText.opacity(0.5))
            Text("Select an image to identify")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.themeSecondaryText)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: 350)
        .padding(.horizontal, 30)
    }
}

struct ActionButtonsView: View {
    @Binding var showingCamera: Bool
    @Binding var selectedItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 20) {
            ActionButton(iconName: "camera.fill", title: "Take Photo") {
                showingCamera = true
            }

            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ActionButtonContent(iconName: "photo.fill.on.rectangle.fill", title: "Choose from Gallery")
            }
        }
        .padding(.horizontal, 40)
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
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Color.appThemePrimary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.themeText)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.themeSecondaryBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
    }
}

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appThemePrimary)
                .cornerRadius(12)
                .shadow(color: Color.appThemePrimary.opacity(0.4), radius: 8, y: 4)
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

