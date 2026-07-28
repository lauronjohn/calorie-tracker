import Foundation

/// Native client for the Anthropic Messages API.
///
/// Uses `output_config.format` (structured outputs) rather than tool use, so there
/// is exactly one decode path and the response is guaranteed to match the schema.
struct AnthropicAnalyzer: FoodAnalyzing {

    let apiKey: String
    let model: String
    var session: URLSession = .analyzerSession

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    func analyze(_ input: AnalysisInput) async throws -> AnalysisResult {
        var content: [[String: Any]] = []

        switch input {
        case .photo(let jpeg):
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": jpeg.base64EncodedString()
                ]
            ])
            content.append(["type": "text", "text": NutritionPrompt.photoInstruction])

        case .text(let description):
            content.append([
                "type": "text",
                "text": NutritionPrompt.textInstruction(description: description)
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "system": NutritionPrompt.system,
            // Thinking is deliberately left at the model default (adaptive). Disabling it
            // on Opus-class models can make them emit tool calls as plain text and leak
            // <thinking> tags; low effort already gives the latency and cost saving.
            "output_config": [
                "effort": "low",
                "format": [
                    "type": "json_schema",
                    "schema": NutritionSchema.schemaObject
                ]
            ],
            "messages": [["role": "user", "content": content]]
        ]

        let text = try await send(body)
        return try NutritionDecoder.decode(text)
    }

    func testConnection() async throws {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16,
            "messages": [["role": "user", "content": "Reply with the single word OK."]]
        ]
        // Any HTTP 200 means the key, model and network path all work. The content
        // itself is irrelevant here, so `requireText` is off.
        _ = try await send(body, requireText: false)
    }

    // MARK: - Transport

    @discardableResult
    private func send(_ body: [String: Any], requireText: Bool = true) async throws -> String {
        guard !apiKey.isEmpty else { throw AnalyzerError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnalyzerError.transport(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw AnalyzerError.http(status: status, body: Self.errorMessage(from: data))
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        // A refusal arrives as HTTP 200 with stop_reason "refusal" — check it before
        // reading content, which may be empty or partial.
        if let stopReason = json["stop_reason"] as? String {
            if stopReason == "refusal" {
                let details = json["stop_details"] as? [String: Any]
                throw AnalyzerError.refused((details?["explanation"] as? String) ?? "")
            }
            if stopReason == "max_tokens" && requireText {
                throw AnalyzerError.truncated
            }
        }

        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()

        if requireText && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AnalyzerError.emptyResponse
        }
        return text
    }

    private static func errorMessage(from data: Data) -> String {
        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return message
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

extension URLSession {
    /// Analysis requests carry an image and can take a while; the default 60s is tight.
    static let analyzerSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
}
