import Foundation

/// Builds the configured analyzer. This is the only place that knows which concrete
/// provider exists — feature code depends on `FoodAnalyzing` alone.
enum AnalyzerFactory {

    static func make(settings: AppSettings) throws -> FoodAnalyzing {
        let provider = settings.provider
        guard let key = KeychainStore.read(account: provider.keychainAccount) else {
            throw AnalyzerError.missingAPIKey
        }

        switch provider {
        case .anthropic:
            return AnthropicAnalyzer(apiKey: key, model: settings.anthropicModel)

        case .openAICompatible:
            return OpenAICompatibleAnalyzer(
                apiKey: key,
                baseURL: settings.openAIBaseURL,
                model: settings.openAIModel
            )
        }
    }
}
