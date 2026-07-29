import XCTest
@testable import CalorieTracker

final class DictationTextTests: XCTestCase {

    func testDictatingIntoAnEmptyFieldUsesTranscriptAlone() {
        XCTAssertEqual(DictationText.merge(base: "", transcript: "two boiled eggs"), "two boiled eggs")
    }

    func testDictationIsAppendedAfterTypedText() {
        XCTAssertEqual(
            DictationText.merge(base: "porridge with berries", transcript: "and a black coffee"),
            "porridge with berries and a black coffee"
        )
    }

    func testWhitespaceIsNormalisedAtTheJoin() {
        XCTAssertEqual(
            DictationText.merge(base: "porridge  ", transcript: "  and coffee "),
            "porridge and coffee"
        )
    }

    func testEmptyTranscriptLeavesTypedTextAlone() {
        XCTAssertEqual(DictationText.merge(base: "porridge", transcript: ""), "porridge")
        XCTAssertEqual(DictationText.merge(base: "porridge", transcript: "   "), "porridge")
    }

    func testBothEmptyIsEmpty() {
        XCTAssertEqual(DictationText.merge(base: "", transcript: ""), "")
    }

    /// Partial results arrive continuously while recording. Merging must rebuild from
    /// the original text each time rather than accumulate, or the field fills with
    /// repeated fragments.
    func testRepeatedPartialResultsDoNotAccumulate() {
        let base = "porridge"
        let partials = ["and", "and a", "and a black", "and a black coffee"]

        var latest = ""
        for partial in partials {
            latest = DictationText.merge(base: base, transcript: partial)
        }

        XCTAssertEqual(latest, "porridge and a black coffee")
    }
}
