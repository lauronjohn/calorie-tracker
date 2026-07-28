import XCTest
@testable import CalorieTracker

/// Stands in for `FoodEntry` so the grouping logic can be tested without SwiftData.
private struct StubEntry: NutritionCarrying {
    let loggedAt: Date
    let totals: MacroTotals
}

final class DayTotalsTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: iso)!
    }

    func testMacroTotalsSumsItems() {
        let items = [
            AnalyzedItem(name: "Eggs", calories: 180, proteinG: 12, carbsG: 1, fatG: 13),
            AnalyzedItem(name: "Toast", calories: 120, proteinG: 4, carbsG: 22, fatG: 1.5)
        ]

        let totals = MacroTotals(items)

        XCTAssertEqual(totals.calories, 300, accuracy: 0.001)
        XCTAssertEqual(totals.protein, 16, accuracy: 0.001)
        XCTAssertEqual(totals.carbs, 23, accuracy: 0.001)
        XCTAssertEqual(totals.fat, 14.5, accuracy: 0.001)
    }

    func testEmptyCollectionTotalsToZero() {
        XCTAssertEqual(MacroTotals([AnalyzedItem]()), .zero)
        XCTAssertEqual(DayTotals.sum([StubEntry]()), .zero)
    }

    func testGroupsEntriesByCalendarDay() {
        let entries = [
            StubEntry(loggedAt: date("2026-07-20T08:00:00Z"), totals: MacroTotals(calories: 400)),
            StubEntry(loggedAt: date("2026-07-20T19:30:00Z"), totals: MacroTotals(calories: 700)),
            StubEntry(loggedAt: date("2026-07-19T12:00:00Z"), totals: MacroTotals(calories: 500))
        ]

        let days = DayTotals.groupedByDay(entries, calendar: calendar)

        XCTAssertEqual(days.count, 2)
        // Newest day first.
        XCTAssertEqual(days[0].totals.calories, 1100, accuracy: 0.001)
        XCTAssertEqual(days[0].entries.count, 2)
        XCTAssertEqual(days[1].totals.calories, 500, accuracy: 0.001)
    }

    func testDayBoundaryIsNotStraddled() {
        // 23:59 and 00:01 are minutes apart but belong to different days.
        let entries = [
            StubEntry(loggedAt: date("2026-07-20T23:59:00Z"), totals: MacroTotals(calories: 100)),
            StubEntry(loggedAt: date("2026-07-21T00:01:00Z"), totals: MacroTotals(calories: 200))
        ]

        XCTAssertEqual(DayTotals.groupedByDay(entries, calendar: calendar).count, 2)
    }

    func testTrailingIncludesDaysWithNoEntries() {
        let entries = [
            StubEntry(loggedAt: date("2026-07-20T08:00:00Z"), totals: MacroTotals(calories: 400))
        ]

        let points = DayTotals.trailing(
            3,
            from: entries,
            endingOn: date("2026-07-22T10:00:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(points.count, 3)
        // Oldest first, so the logged day is index 0 and the two silent days follow.
        XCTAssertEqual(points[0].totals.calories, 400, accuracy: 0.001)
        XCTAssertEqual(points[1].totals.calories, 0, accuracy: 0.001)
        XCTAssertEqual(points[2].totals.calories, 0, accuracy: 0.001)
    }

    func testTrailingWithZeroDaysIsEmpty() {
        XCTAssertTrue(DayTotals.trailing(0, from: [StubEntry](), calendar: calendar).isEmpty)
    }
}
