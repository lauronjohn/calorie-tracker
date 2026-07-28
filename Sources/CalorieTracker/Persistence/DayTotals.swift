import Foundation

/// Anything that carries a set of macros — a persisted `FoodItem` or a freshly
/// analysed `AnalyzedItem`. Lets totals be computed the same way everywhere.
protocol MacroProviding {
    var calories: Double { get }
    var proteinG: Double { get }
    var carbsG: Double { get }
    var fatG: Double { get }
}

extension FoodItem: MacroProviding {}

/// A summed set of macros. Deliberately computed on-device: the model is asked
/// for per-item numbers only, never for totals.
struct MacroTotals: Equatable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static let zero = MacroTotals()

    init(calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    init<C: Collection>(_ items: C) where C.Element: MacroProviding {
        for item in items {
            calories += item.calories
            protein += item.proteinG
            carbs += item.carbsG
            fat += item.fatG
        }
    }

    static func + (lhs: MacroTotals, rhs: MacroTotals) -> MacroTotals {
        MacroTotals(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }
}

/// Implemented by `FoodEntry`; also implementable by a plain struct in tests, which
/// is why the grouping helpers below never touch SwiftData.
protocol NutritionCarrying {
    var loggedAt: Date { get }
    var totals: MacroTotals { get }
}

/// One calendar day's worth of entries.
struct DaySummary<T: NutritionCarrying>: Identifiable {
    let day: Date
    let entries: [T]
    let totals: MacroTotals

    var id: Date { day }
}

/// One point on the trends chart. A named type rather than a tuple because Swift has
/// no key paths into tuple elements, and `ForEach`/`Chart` need an identity.
struct DayPoint: Identifiable, Equatable {
    let day: Date
    let totals: MacroTotals

    var id: Date { day }
}

enum DayTotals {
    static func sum<T: NutritionCarrying>(_ entries: [T]) -> MacroTotals {
        entries.reduce(MacroTotals.zero) { $0 + $1.totals }
    }

    /// Groups entries into calendar days, newest day first. Entries within a day
    /// keep their relative order.
    static func groupedByDay<T: NutritionCarrying>(
        _ entries: [T],
        calendar: Calendar = .current
    ) -> [DaySummary<T>] {
        let buckets = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.loggedAt) }
        return buckets
            .map { DaySummary(day: $0.key, entries: $0.value, totals: sum($0.value)) }
            .sorted { $0.day > $1.day }
    }

    /// Day-by-day totals for the last `days` days ending today, including days with
    /// no entries (so charts do not silently close gaps).
    static func trailing<T: NutritionCarrying>(
        _ days: Int,
        from entries: [T],
        endingOn end: Date = .now,
        calendar: Calendar = .current
    ) -> [DayPoint] {
        let today = calendar.startOfDay(for: end)
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.loggedAt) }

        return (0..<max(days, 0)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayPoint(day: day, totals: sum(byDay[day] ?? []))
        }
    }
}
