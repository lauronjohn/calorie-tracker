import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openAICompatible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openAICompatible: return "OpenAI-compatible"
        }
    }

    /// Keychain account name — separate entries so switching providers does not
    /// make you re-paste the other one's key.
    var keychainAccount: String { "apikey.\(rawValue)" }

    var keyHint: String {
        switch self {
        case .anthropic: return "From console.anthropic.com. Starts with sk-ant-."
        case .openAICompatible: return "From whichever provider your base URL points at."
        }
    }
}

/// Provider presets offered in Settings. Base URL and model stay editable — these
/// are starting points, not a closed list.
struct ProviderPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let baseURL: String
    let model: String

    static let all: [ProviderPreset] = [
        ProviderPreset(
            id: "qwen",
            name: "Qwen (Alibaba Model Studio)",
            baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
            model: "qwen3-vl-plus"
        ),
        ProviderPreset(
            id: "openrouter",
            name: "OpenRouter",
            baseURL: "https://openrouter.ai/api/v1",
            model: "qwen/qwen3-vl-235b-a22b-instruct"
        ),
        ProviderPreset(
            id: "openai",
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o"
        )
    ]
}

/// App configuration. Small scalars only, so `UserDefaults` rather than SwiftData.
final class AppSettings: ObservableObject {

    private enum Keys {
        static let provider = "settings.provider"
        static let anthropicModel = "settings.anthropic.model"
        static let openAIBaseURL = "settings.openai.baseURL"
        static let openAIModel = "settings.openai.model"
        static let goalCalories = "settings.goal.calories"
        static let goalProtein = "settings.goal.protein"
        static let goalCarbs = "settings.goal.carbs"
        static let goalFat = "settings.goal.fat"
    }

    private let defaults: UserDefaults

    @Published var provider: AIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }
    @Published var anthropicModel: String {
        didSet { defaults.set(anthropicModel, forKey: Keys.anthropicModel) }
    }
    @Published var openAIBaseURL: String {
        didSet { defaults.set(openAIBaseURL, forKey: Keys.openAIBaseURL) }
    }
    @Published var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: Keys.openAIModel) }
    }

    @Published var goalCalories: Double {
        didSet { defaults.set(goalCalories, forKey: Keys.goalCalories) }
    }
    @Published var goalProtein: Double {
        didSet { defaults.set(goalProtein, forKey: Keys.goalProtein) }
    }
    @Published var goalCarbs: Double {
        didSet { defaults.set(goalCarbs, forKey: Keys.goalCarbs) }
    }
    @Published var goalFat: Double {
        didSet { defaults.set(goalFat, forKey: Keys.goalFat) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedProvider = defaults.string(forKey: Keys.provider) ?? AIProvider.anthropic.rawValue
        self.provider = AIProvider(rawValue: storedProvider) ?? .anthropic

        self.anthropicModel = defaults.string(forKey: Keys.anthropicModel) ?? "claude-opus-5"
        self.openAIBaseURL = defaults.string(forKey: Keys.openAIBaseURL)
            ?? ProviderPreset.all[0].baseURL
        self.openAIModel = defaults.string(forKey: Keys.openAIModel)
            ?? ProviderPreset.all[0].model

        self.goalCalories = defaults.object(forKey: Keys.goalCalories) as? Double ?? 2000
        self.goalProtein = defaults.object(forKey: Keys.goalProtein) as? Double ?? 150
        self.goalCarbs = defaults.object(forKey: Keys.goalCarbs) as? Double ?? 200
        self.goalFat = defaults.object(forKey: Keys.goalFat) as? Double ?? 65
    }

    var goals: MacroTotals {
        MacroTotals(calories: goalCalories, protein: goalProtein, carbs: goalCarbs, fat: goalFat)
    }
}
