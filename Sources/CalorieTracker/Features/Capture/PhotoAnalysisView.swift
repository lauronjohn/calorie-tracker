import SwiftUI
import PhotosUI

/// Pick a photo, analyse it, review the estimate, save. Presented as a sheet.
struct PhotoAnalysisView: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow = AnalysisFlowModel()

    @State private var jpegData: Data?
    @State private var preview: UIImage?
    @State private var showingCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var pickError: String?

    var body: some View {
        NavigationStack {
            switch flow.phase {
            case .idle:
                chooser
            case .analyzing:
                analysing
            case .review(let result):
                AnalysisReviewView(
                    result: result,
                    imageData: jpegData,
                    source: .photo,
                    onSaved: { dismiss() }
                )
            case .failed(let message):
                failure(message)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                onImage: { image in Task { await start(with: image) } },
                onFinish: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task { await loadFromLibrary(item) }
        }
    }

    // MARK: - Phases

    private var chooser: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Photograph your meal and it will be broken down into items with calories and macros.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if CameraPicker.isAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if !CameraPicker.isAvailable {
                Text("No camera on this device — the simulator has none, so use Choose photo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let pickError {
                Text(pickError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .navigationTitle("Add from photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
    }

    private var analysing: some View {
        VStack(spacing: 20) {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            ProgressView("Estimating…")
            Text("This usually takes a few seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .navigationTitle("Add from photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Could not analyse that photo")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let jpegData {
                Button("Try again") {
                    Task { await flow.analyze(.photo(jpegData), settings: settings) }
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Pick another photo") {
                libraryItem = nil
                flow.reset()
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .navigationTitle("Add from photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    // MARK: - Work

    @MainActor
    private func loadFromLibrary(_ item: PhotosPickerItem) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            pickError = "That photo could not be loaded. Try a different one."
            return
        }
        await start(with: image)
    }

    @MainActor
    private func start(with image: UIImage) async {
        showingCamera = false
        pickError = nil

        guard let jpeg = ImageProcessing.prepareForUpload(image) else {
            pickError = "That photo could not be prepared for upload."
            return
        }

        jpegData = jpeg
        preview = UIImage(data: jpeg)
        await flow.analyze(.photo(jpeg), settings: settings)
    }
}
