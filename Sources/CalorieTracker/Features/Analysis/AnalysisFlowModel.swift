import Foundation

/// Drives one analysis, from request to reviewable result. Shared by the photo and
/// manual-entry flows so both behave identically on slow networks and errors.
@MainActor
final class AnalysisFlowModel: ObservableObject {

    enum Phase {
        case idle
        case analyzing
        case review(AnalysisResult)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    func analyze(_ input: AnalysisInput, settings: AppSettings) async {
        phase = .analyzing
        do {
            let analyzer = try AnalyzerFactory.make(settings: settings)
            phase = .review(try await analyzer.analyze(input))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        phase = .idle
    }
}
