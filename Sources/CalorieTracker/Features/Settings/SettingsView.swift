import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings

    @State private var apiKeyInput = ""
    @State private var keySaved = false
    @State private var testState: TestState = .idle

    private enum TestState {
        case idle
        case testing
        case success
        case failure(String)
    }

    private let claudeModels = ["claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5"]

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                modelSection
                keySection
                goalsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear(perform: refreshKeyState)
            .onChange(of: settings.provider) { _, _ in
                apiKeyInput = ""
                testState = .idle
                refreshKeyState()
            }
        }
    }

    // MARK: - Sections

    private var providerSection: some View {
        Section {
            Picker("Provider", selection: $settings.provider) {
                ForEach(AIProvider.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Provider")
        } footer: {
            Text("“OpenAI-compatible” covers Qwen, OpenRouter, OpenAI and anything else speaking the OpenAI chat API — you only change the base URL and model.")
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        switch settings.provider {
        case .anthropic:
            Section {
                TextField("Model", text: $settings.anthropicModel)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Menu("Common models") {
                    ForEach(claudeModels, id: \.self) { model in
                        Button(model) {
                            settings.anthropicModel = model
                            testState = .idle
                        }
                    }
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Opus is the most accurate and costs roughly 2¢ per photo; Sonnet about half that; Haiku least of all.")
            }

        case .openAICompatible:
            Section {
                Menu("Use a preset") {
                    ForEach(ProviderPreset.all) { preset in
                        Button(preset.name) {
                            settings.openAIBaseURL = preset.baseURL
                            settings.openAIModel = preset.model
                            testState = .idle
                        }
                    }
                }

                TextField("Base URL", text: $settings.openAIBaseURL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                TextField("Model", text: $settings.openAIModel)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Endpoint")
            } footer: {
                Text("Include the version path — e.g. …/compatible-mode/v1. The model must accept images; a text-only model will fail on the photo flow.")
            }
        }
    }

    private var keySection: some View {
        Section {
            SecureField(keySaved ? "Replace saved key" : "Paste your API key", text: $apiKeyInput)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                Button("Save key") {
                    KeychainStore.save(apiKeyInput, account: settings.provider.keychainAccount)
                    apiKeyInput = ""
                    testState = .idle
                    refreshKeyState()
                }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                if keySaved {
                    Button("Remove", role: .destructive) {
                        KeychainStore.delete(account: settings.provider.keychainAccount)
                        testState = .idle
                        refreshKeyState()
                    }
                }
            }

            Button(action: runTest) {
                HStack {
                    Text("Test connection")
                    Spacer()
                    testStatusView
                }
            }
            .disabled(!keySaved || isTesting)

            if case .failure(let message) = testState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("API key")
        } footer: {
            Text("\(settings.provider.keyHint) Stored in the iOS Keychain on this device and sent only to the provider above. Each provider keeps its own saved key.")
        }
    }

    private var goalsSection: some View {
        Section {
            goalField("Calories", unit: "kcal", value: $settings.goalCalories)
            goalField("Protein", unit: "g", value: $settings.goalProtein)
            goalField("Carbs", unit: "g", value: $settings.goalCarbs)
            goalField("Fat", unit: "g", value: $settings.goalFat)
        } header: {
            Text("Daily goals")
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Estimates from a photo are estimates. Every result is shown for review before it is logged, with a confidence level per item and the assumptions behind the numbers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("About the numbers")
        }
    }

    // MARK: - Pieces

    private var isTesting: Bool {
        if case .testing = testState { return true }
        return false
    }

    @ViewBuilder
    private var testStatusView: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private func goalField(_ label: String, unit: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number.precision(.fractionLength(0)))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func refreshKeyState() {
        keySaved = KeychainStore.hasKey(account: settings.provider.keychainAccount)
    }

    private func runTest() {
        testState = .testing
        Task { @MainActor in
            do {
                let analyzer = try AnalyzerFactory.make(settings: settings)
                try await analyzer.testConnection()
                testState = .success
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}
