import Foundation

/// The single source of truth for the nutrition contract. Both providers send the
/// same prompt and the same schema, so results stay comparable when you switch.
enum NutritionSchema {

    static let schemaJSON = """
    {
      "type": "object",
      "properties": {
        "items": {
          "type": "array",
          "description": "One entry per distinct food or drink.",
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string", "description": "Short name, e.g. 'grilled chicken breast'." },
              "portion": { "type": "string", "description": "Estimated portion, e.g. 'about 150 g' or '1 medium bowl'." },
              "calories": { "type": "number", "description": "Estimated kcal for this portion." },
              "protein_g": { "type": "number" },
              "carbs_g": { "type": "number" },
              "fat_g": { "type": "number" },
              "confidence": { "type": "string", "enum": ["high", "medium", "low"] }
            },
            "required": ["name", "portion", "calories", "protein_g", "carbs_g", "fat_g", "confidence"],
            "additionalProperties": false
          }
        },
        "assumptions": {
          "type": "array",
          "description": "Assumptions that materially affect the numbers, e.g. cooking method or hidden oil.",
          "items": { "type": "string" }
        },
        "note": {
          "type": "string",
          "description": "One short sentence, or an empty string. Use it to flag anything unreadable."
        }
      },
      "required": ["items", "assumptions", "note"],
      "additionalProperties": false
    }
    """

    /// The schema as a Foundation object, for embedding in a JSON request body.
    static let schemaObject: [String: Any] = {
        guard
            let data = schemaJSON.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            assertionFailure("NutritionSchema.schemaJSON is not valid JSON")
            return [:]
        }
        return object
    }()
}

enum NutritionPrompt {

    static let system = """
    You estimate the nutritional content of meals.

    Break the meal into its distinct foods and drinks. For each one, estimate the \
    portion and then the calories, protein, carbohydrates and fat for that portion. \
    Use kcal for calories and grams for macros.

    Rules:
    - Do not return totals. Report per-item numbers only; totals are computed elsewhere.
    - Estimate portions from visible cues: plate and utensil size, packaging, and how \
      the food is stacked or spread.
    - Account for cooking fat, sauces, and dressings you can reasonably infer, and say \
      so in "assumptions".
    - Set "confidence" per item: "high" when the food and portion are both clear, \
      "medium" when one is uncertain, "low" when you are largely guessing.
    - Never refuse to estimate because the image is imperfect. Give your best estimate \
      and mark it low confidence instead.
    - If there is no food at all, return an empty "items" array and say so in "note".
    - Keep "assumptions" to the few that would actually change the numbers.
    """

    static let photoInstruction = """
    Estimate the nutrition of the meal in this photo.
    """

    static func textInstruction(description: String) -> String {
        """
        Estimate the nutrition of this meal, described by the person eating it:

        \(description)
        """
    }

    /// Appended for OpenAI-compatible endpoints that cannot enforce a JSON schema
    /// server-side, so the shape is at least stated in the prompt.
    static let schemaInstruction = """
    Reply with a single JSON object and nothing else — no prose, no markdown fences. \
    It must conform to this JSON Schema:

    \(NutritionSchema.schemaJSON)
    """
}

/// Turns whatever text a provider returned into an `AnalysisResult`.
enum NutritionDecoder {

    static func decode(_ raw: String) throws -> AnalysisResult {
        guard let json = extractJSONObject(from: raw) else {
            throw AnalyzerError.decoding(raw: raw)
        }
        do {
            return try JSONDecoder().decode(AnalysisResult.self, from: Data(json.utf8))
        } catch {
            throw AnalyzerError.decoding(raw: raw)
        }
    }

    /// Providers that cannot enforce a schema sometimes wrap JSON in ```json fences
    /// or add a sentence before it. Take the outermost balanced object instead of
    /// trusting the whole string.
    static func extractJSONObject(from raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]

            if escaped {
                escaped = false
            } else if character == "\\" && inString {
                escaped = true
            } else if character == "\"" {
                inString.toggle()
            } else if !inString {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...index])
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }
}
