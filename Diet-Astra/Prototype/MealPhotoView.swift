import AVFoundation
import PhotosUI
import SwiftUI

struct MealPhotoView: View {
    let data: Data?
    var body: some View {
        GeometryReader { geometry in
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .accessibilityLabel("Meal photo")
            } else {
                MealImagePlaceholder()
            }
        }
    }
}

struct MealPhotoSource: View {
    @Binding var photoData: Data?
    @Binding var loading: Bool
    @State private var selection: PhotosPickerItem?
    @State private var showingCamera = false
    @Binding var errorMessage: String?

    var body: some View {
        HStack {
            Button {
                Task { await openCamera() }
            } label: { Label("Take photo", systemImage: "camera") }
                .accessibilityIdentifier("takeMealPhoto")
            Spacer()
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
            }.accessibilityIdentifier("chooseMealPhoto")
        }
        .buttonStyle(.bordered).controlSize(.large)
        .disabled(loading)
        .fullScreenCover(isPresented: $showingCamera) {
            MealCamera { image in
                if let image {
                    photoData = Self.prepare(image)
                    if photoData == nil { errorMessage = "This photo could not be opened. Please try another." }
                }
                showingCamera = false
            }.ignoresSafeArea()
        }
        .task(id: selection) {
            guard let selection else { return }
            loading = true
            defer { loading = false }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self),
                      let image = UIImage(data: data), let prepared = Self.prepare(image) else {
                    errorMessage = "This photo could not be opened. Please try another."
                    return
                }
                try Task.checkCancellation()
                photoData = prepared
            } catch is CancellationError { } catch {
                errorMessage = "Could not load this photo. Try a photo downloaded to your device."
            }
        }
    }

    private func openCamera() async {
        #if targetEnvironment(simulator)
        errorMessage = "Take photo requires a physical iPhone. In the simulator, choose a photo from the library instead."
        return
        #else
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "The simulator has no camera. Choose a photo from the library, or try Take photo on an iPhone."
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var allowed = status == .authorized
        if status == .notDetermined { allowed = await requestCamera() }
        if allowed { showingCamera = true } else {
            errorMessage = "Camera access is off. You can enable it in iPhone Settings or choose a photo instead."
        }
        #endif
    }

    private func requestCamera() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // Bound memory use and discard source metadata; analysis photos remain temporary; source location metadata is not transmitted.
    private static func prepare(_ image: UIImage) -> Data? {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.8)
    }
}

private struct MealCamera: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion(info[.originalImage] as? UIImage)
        }
    }
}
