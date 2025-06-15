import SwiftUI
import PhotosUI // For PHPickerViewController

struct CameraGalleryView: View {
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    @State private var navigateToResults = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                Text("Identify a Bug")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let inputImage = inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                        .padding()
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding()
                }

                HStack(spacing: 20) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                    }

                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        Label("Gallery", systemImage: "photo.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                if inputImage != nil {
                    Button {
                        // Placeholder for API call
                        // For now, just navigate to results
                        navigateToResults = true
                    } label: {
                        Text("Identify Bug")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: ResultsView(identifiedBugName: "Sample Bug", confidence: 0.95, imageUrl: inputImage), isActive: $navigateToResults) {
                    EmptyView()
                }
            }
            .navigationTitle("Capture or Select")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $inputImage)
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        inputImage = UIImage(data: data)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Added for better navigation appearance
    }
}

// ImagePicker for Camera
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
