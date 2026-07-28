import Foundation

/// What we send to a provider for analysis.
enum AnalysisInput {
    /// Already downscaled and JPEG-encoded — see `ImageProcessing`.
    case photo(Data)
    case text(String)
}

/// One food the model identified. Numbers are estimates; `confidence` and the
/// result's `assumptions` exist so the UI can present them as such.
struct AnalyzedItem: Codable, Hashable, MacroProviding {
    var name: String
    var portion: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var confidence: Confidence

    enum CodingKeys: String, CodingKey {
        case name
        case portion
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case confidence
    }

    init(
        name: String,
        portion: String = "",
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        confidence: Confidence = .medium
    ) {
        self.name = name
        self.portion = portion
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.confidence = confidence
    }

    /// Hand-written because OpenAI-compatible endpoints without JSON-schema support
    /// sometimes return numbers as strings, or a confidence value outside the enum.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Unknown item"
        portion = (try? c.decode(String.self, forKey: .portion)) ?? ""
        calories = Self.number(c, .calories)
        proteinG = Self.number(c, .proteinG)
        carbsG = Self.number(c, .carbsG)
        fatG = Self.number(c, .fatG)
        let rawConfidence = (try? c.decode(String.self, forKey: .confidence))?.lowercased()
        confidence = Confidence(rawValue: rawConfidence ?? "") ?? .medium
    }

    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let value = try? c.decode(Double.self, forKey: key) { return value }
        if let value = try? c.decode(Int.self, forKey: key) { return Double(value) }
        if let text = try? c.decode(String.self, forKey: key) {
            let digits = text.filter { $0.isNumber || $0 == "." || $0 == "-" }
            return Double(digits) ?? 0
        }
        return 0
    }
}

/// The full result of one analysis. Note there is no `total` field — totals are
/// summed on-device from `items`.
struct AnalysisResult: Codable {
    var items: [AnalyzedItem]
    var assumptions: [String]
    var note: String

    init(items: [AnalyzedItem], assumptions: [String] = [], note: String = "") {
        self.items = items
        self.assumptions = assumptions
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decode([AnalyzedItem].self, forKey: .items)
        assumptions = (try? c.decode([String].self, forKey: .assumptions)) ?? []
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
    }

    var totals: MacroTotals { MacroTotals(items) }
}

// MARK: - Provider interface

protocol FoodAnalyzing {
    /// Analyse a photo or a text description into per-item nutrition estimates.
    func analyze(_ input: AnalysisInput) async throws -> AnalysisResult

    /// A cheap request used by Settings to prove the key, base URL and model work.
    /// Succeeds on any HTTP 200 — it is a credentials check, not a quality check.
    func testConnection() async throws
}

enum AnalyzerError: LocalizedError {
    case missingAPIKey
    case invalidBaseURL(String)
    case http(status: Int, body: String)
    case refused(String)
    case truncated
    case emptyResponse
    case decoding(raw: String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key saved. Add one in Settings."
        case .invalidBaseURL(let url):
            return "Base URL is not valid: \(url)"
        case .http(let status, let body):
            return "Provider returned HTTP \(status). \(Self.condense(body))"
        case .refused(let explanation):
            return explanation.isEmpty
                ? "The model declined to answer this request."
                : "The model declined to answer: \(explanation)"
        case .truncated:
            return "The response was cut off before it finished. Try again, or use a shorter description."
        case .emptyResponse:
            return "The provider returned an empty response."
        case .decoding(let raw):
            return "Could not read the provider's response as nutrition data. It said: \(Self.condense(raw))"
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    /// Provider error bodies can be enormous; keep the surfaced text readable.
    private static func condense(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 300 ? String(trimmed.prefix(300)) + "…" : trimmed
    }
}
