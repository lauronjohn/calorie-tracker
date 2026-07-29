import SwiftUI

/// Speak or type what you ate and get the same per-item breakdown as the photo flow.
/// Also the fallback when a photo is too ambiguous to read.
struct ManualEntryView: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow = AnalysisFlowModel()
    @StateObject private var dictation = DictationRecorder()

    @State private var description = ""
    /// What was in the field when dictation started, so partial results can be
    /// re-merged rather than appended over and over.
    @State private var descriptionBeforeDictation = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            switch flow.phase {
            case .idle:
                form
            case .analyzing:
                analysing
            case .review(let result):
                AnalysisReviewView(
                    result: result,
                    imageData: nil,
                    source: .manual,
                    onSaved: { dismiss() }
                )
            case .failed(let message):
                failure(message)
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField(
                    "e.g. two scrambled eggs, sourdough toast with butter, flat white",
                    text: $description,
                    axis: .vertical
                )
                .lineLimit(3...8)
                .focused($focused)

                if dictation.isSupported {
                    Button {
                        Task { await toggleDictation() }
                    } label: {
                        Label(
                            dictation.isRecording ? "Stop dictating" : "Dictate",
                            systemImage: dictation.isRecording ? "stop.circle.fill" : "mic.fill"
                        )
                        .foregroundStyle(dictation.isRecording ? Color.red : Color.accentColor)
                        .symbolEffect(.pulse, isActive: dictation.isRecording)
                    }
                }

                if let message = dictation.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("What did you eat?")
            } footer: {
                Text(dictation.isRecording
                     ? "Listening — speak naturally, then tap Stop. You can edit the text before estimating."
                     : "Portions help a lot — “a large bowl”, “about 200 g”, “half a plate”.")
            }

            Section {
                Button("Estimate", action: estimate)
                    .disabled(
                        dictation.isRecording
                        || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
            }
        }
        .navigationTitle("Add a meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
        .onChange(of: dictation.transcript) { _, transcript in
            description = DictationText.merge(base: descriptionBeforeDictation, transcript: transcript)
        }
        .onDisappear { dictation.stop() }
    }

    private var analysing: some View {
        VStack(spacing: 16) {
            ProgressView("Estimating…")
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxHeight: .infinity)
        .navigationTitle("Add a meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Could not estimate that")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try again", action: estimate)
                .buttonStyle(.borderedProminent)

            Button("Edit description") { flow.reset() }
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .navigationTitle("Add a meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    private func toggleDictation() async {
        if dictation.isRecording {
            dictation.stop()
        } else {
            // Dismiss the keyboard first — it covers the transcript as it comes in.
            focused = false
            descriptionBeforeDictation = description
            await dictation.start()
        }
    }

    private func estimate() {
        focused = false
        dictation.stop()
        Task { await flow.analyze(.text(description), settings: settings) }
    }
}
