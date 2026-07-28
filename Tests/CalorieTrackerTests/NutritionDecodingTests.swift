import XCTest
@testable import CalorieTracker

final class NutritionDecodingTests: XCTestCase {

    /// The shape a schema-enforcing provider returns.
    private let clean = """
    {
      "items": [
        {
          "name": "grilled chicken breast",
          "portion": "about 150 g",
          "calories": 248,
          "protein_g": 46.5,
          "carbs_g": 0,
          "fat_g": 5.4,
          "confidence": "high"
        },
        {
          "name": "steamed broccoli",
          "portion": "1 cup",
          "calories": 55,
          "protein_g": 3.7,
          "carbs_g": 11.2,
          "fat_g": 0.6,
          "confidence": "medium"
        }
      ],
      "assumptions": ["cooked without added oil"],
      "note": ""
    }
    """

    func testDecodesSchemaConformingResponse() throws {
        let result = try NutritionDecoder.decode(clean)

        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].name, "grilled chicken breast")
        XCTAssertEqual(result.items[0].confidence, .high)
        XCTAssertEqual(result.assumptions, ["cooked without added oil"])
        XCTAssertEqual(result.totals.calories, 303, accuracy: 0.001)
        XCTAssertEqual(result.totals.protein, 50.2, accuracy: 0.001)
    }

    func testDecodesFencedResponseWithSurroundingProse() throws {
        let raw = """
        Sure! Here is the breakdown:

        ```json
        \(clean)
        ```

        Let me know if you'd like more detail.
        """

        let result = try NutritionDecoder.decode(raw)
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.totals.calories, 303, accuracy: 0.001)
    }

    func testDecodesNumbersReturnedAsStrings() throws {
        let raw = """
        {"items":[{"name":"Rice","portion":"1 bowl","calories":"205",
        "protein_g":"4.3","carbs_g":"45","fat_g":"0.4","confidence":"medium"}],
        "assumptions":[],"note":""}
        """

        let result = try NutritionDecoder.decode(raw)
        XCTAssertEqual(result.items[0].calories, 205, accuracy: 0.001)
        XCTAssertEqual(result.items[0].proteinG, 4.3, accuracy: 0.001)
    }

    func testUnknownConfidenceFallsBackToMedium() throws {
        let raw = """
        {"items":[{"name":"Soup","portion":"1 bowl","calories":150,
        "protein_g":5,"carbs_g":18,"fat_g":6,"confidence":"fairly sure"}],
        "assumptions":[],"note":""}
        """

        XCTAssertEqual(try NutritionDecoder.decode(raw).items[0].confidence, .medium)
    }

    func testMissingOptionalFieldsAreTolerated() throws {
        // No `assumptions`, no `note` — providers without schema enforcement drop them.
        let raw = """
        {"items":[{"name":"Apple","portion":"1 medium","calories":95,
        "protein_g":0.5,"carbs_g":25,"fat_g":0.3,"confidence":"high"}]}
        """

        let result = try NutritionDecoder.decode(raw)
        XCTAssertTrue(result.assumptions.isEmpty)
        XCTAssertEqual(result.note, "")
    }

    func testEmptyItemsIsValid() throws {
        let raw = #"{"items":[],"assumptions":[],"note":"No food is visible in this photo."}"#

        let result = try NutritionDecoder.decode(raw)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.totals, .zero)
        XCTAssertEqual(result.note, "No food is visible in this photo.")
    }

    func testNestedBracesInStringsDoNotTruncateExtraction() {
        let raw = #"prefix {"items":[],"assumptions":[],"note":"a } brace and a \" quote"} suffix"#

        let extracted = NutritionDecoder.extractJSONObject(from: raw)
        XCTAssertEqual(extracted, #"{"items":[],"assumptions":[],"note":"a } brace and a \" quote"}"#)
    }

    func testNonJSONResponseThrows() {
        XCTAssertThrowsError(try NutritionDecoder.decode("I'm sorry, I can't help with that.")) { error in
            guard case AnalyzerError.decoding = error else {
                return XCTFail("Expected AnalyzerError.decoding, got \(error)")
            }
        }
    }

    func testSchemaIsValidJSON() throws {
        let data = Data(NutritionSchema.schemaJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(object?["properties"])
        XCTAssertFalse(NutritionSchema.schemaObject.isEmpty)
    }

    func testCompletionsURLNormalisesTrailingSlash() {
        XCTAssertEqual(
            OpenAICompatibleAnalyzer.completionsURL(from: "https://example.com/v1/")?.absoluteString,
            "https://example.com/v1/chat/completions"
        )
        XCTAssertNil(OpenAICompatibleAnalyzer.completionsURL(from: "   "))
        XCTAssertNil(OpenAICompatibleAnalyzer.completionsURL(from: "ftp://example.com/v1"))
    }
}
