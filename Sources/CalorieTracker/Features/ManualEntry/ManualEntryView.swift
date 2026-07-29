import SwiftUI

/// Type what you ate and get the same per-item breakdown as the photo flow.
/// Also the fallback when a photo is too ambiguous to read.
struct ManualEntryView: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow = AnalysisFlowModel()

    @State private var description = ""
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
            } header: {
                Text("What did you eat?")
            } footer: {
                Text("Portions help a lot — “a large bowl”, “about 200 g”, “half a plate”.")
            }

            Section {
                Button("Estimate", action: estimate)
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Add by text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
        .onAppear { focused = true }
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
        .navigationTitle("Add by text")
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
        .navigationTitle("Add by text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { cancelButton }
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    private func estimate() {
        focused = false
        Task { await flow.analyze(.text(description), settings: settings) }
    }
}
