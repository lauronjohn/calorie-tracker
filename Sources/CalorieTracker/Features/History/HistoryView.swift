import SwiftUI
import SwiftData

struct HistoryView: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context

    @Query(sort: \FoodEntry.date, order: .reverse)
    private var entries: [FoodEntry]

    @State private var range: TrendRange = .week

    private var days: [DaySummary<FoodEntry>] {
        DayTotals.groupedByDay(entries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(TrendRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    TrendsChartView(
                        points: DayTotals.trailing(range.rawValue, from: entries),
                        goal: settings.goalCalories
                    )
                    .listRowSeparator(.hidden)
                }

                if days.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "calendar",
                        description: Text("Meals you log will be grouped by day here.")
                    )
                } else {
                    ForEach(days) { day in
                        Section {
                            ForEach(day.entries) { entry in
                                EntryRow(entry: entry)
                            }
                            .onDelete { offsets in
                                delete(offsets, from: day.entries)
                            }
                        } header: {
                            HStack {
                                Text(dayTitle(day.day))
                                Spacer()
                                Text("\(Int(day.totals.calories.rounded())) kcal")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private func delete(_ offsets: IndexSet, from dayEntries: [FoodEntry]) {
        for index in offsets {
            context.delete(dayEntries[index])
        }
        try? context.save()
    }
}
