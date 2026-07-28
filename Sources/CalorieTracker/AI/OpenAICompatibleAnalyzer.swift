import Foundation

/// Client for any endpoint speaking the OpenAI chat-completions wire format:
/// Qwen via Alibaba Model Studio, OpenRouter, OpenAI itself, or a local server.
///
/// Structured-output support varies across these endpoints, so the request walks a
/// ladder — JSON schema, then JSON mode, then plain text — and the decoder tolerates
/// markdown fences and leading prose.
struct OpenAICompatibleAnalyzer: FoodAnalyzing {

    let apiKey: String
    let baseURL: String
    let model: String
    var session: URLSession = .analyzerSession

    func analyze(_ input: AnalysisInput) async throws -> AnalysisResult {
        var parts: [[String: Any]] = []

        switch input {
        case .photo(let jpeg):
            parts.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]
            ])
            parts.append(["type": "text", "text": NutritionPrompt.photoInstruction])

        case .text(let description):
            parts.append([
                "type": "text",
                "text": NutritionPrompt.textInstruction(description: description)
            ])
        }

        var lastError: Error?
        for format in Self.responseFormatLadder {
            do {
                let text = try await send(userParts: parts, responseFormat: format)
                return try NutritionDecoder.decode(text)
            } catch AnalyzerError.http(let status, let body) where status == 400 || status == 422 {
                // Most likely the endpoint rejected `response_format`. Step down and retry.
                lastError = AnalyzerError.http(status: status, body: body)
                continue
            }
        }
        throw lastError ?? AnalyzerError.emptyResponse
    }

    func testConnection() async throws {
        _ = try await send(
            userParts: [["type": "text", "text": "Reply with the single word OK."]],
            responseFormat: nil,
            maxTokens: 16,
            requireText: false
        )
    }

    /// Preferred first, most permissive last.
    private static let responseFormatLadder: [[String: Any]?] = [
        [
            "type": "json_schema",
            "json_schema": [
                "name": "nutrition_estimate",
                "strict": true,
                "schema": NutritionSchema.schemaObject
            ]
        ],
        ["type": "json_object"],
        nil
    ]

    // MARK: - Transport

    @discardableResult
    private func send(
        userParts: [[String: Any]],
        responseFormat: [String: Any]?,
        maxTokens: Int = 2000,
        requireText: Bool = true
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AnalyzerError.missingAPIKey }
        guard let url = Self.completionsURL(from: baseURL) else {
            throw AnalyzerError.invalidBaseURL(baseURL)
        }

        // The schema is restated in the prompt because the two lower rungs of the
        // ladder have no server-side enforcement.
        let system = NutritionPrompt.system + "\n\n" + NutritionPrompt.schemaInstruction

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userParts]
            ]
        ]
        if let responseFormat {
            body["response_format"] = responseFormat
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
        guard
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            throw AnalyzerError.emptyResponse
        }

        if let refusal = message["refusal"] as? String, !refusal.isEmpty {
            throw AnalyzerError.refused(refusal)
        }

        let text = Self.text(from: message["content"])
        if requireText && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if choices.first?["finish_reason"] as? String == "length" {
                throw AnalyzerError.truncated
            }
            throw AnalyzerError.emptyResponse
        }
        return text
    }

    /// `content` is normally a string, but some servers return an array of parts.
    private static func text(from content: Any?) -> String {
        if let string = content as? String { return string }
        if let parts = content as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined()
        }
        return ""
    }

    static func completionsURL(from baseURL: String) -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard !trimmed.isEmpty, let url = URL(string: trimmed + "/chat/completions") else { return nil }
        guard url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    private static func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            // DashScope returns a flat `message` on some error paths.
            if let message = json["message"] as? String {
                return message
            }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
