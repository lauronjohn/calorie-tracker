import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context

    @Query(sort: \FoodEntry.date, order: .reverse)
    private var entries: [FoodEntry]

    @State private var showingPhoto = false
    @State private var showingManual = false
    @State private var hasKey = true

    private var todaysEntries: [FoodEntry] {
        entries.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var totals: MacroTotals {
        DayTotals.sum(todaysEntries)
    }

    var body: some View {
        NavigationStack {
            List {
                if !hasKey {
                    Section {
                        Label(
                            "Add an API key in Settings before logging by photo or text.",
                            systemImage: "key"
                        )
                        .font(.footnote)
                    }
                }

                Section {
                    VStack(spacing: 24) {
                        CalorieRingView(consumed: totals.calories, goal: settings.goalCalories)
                        MacroBarsView(totals: totals, goals: settings.goals)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section("Today") {
                    if todaysEntries.isEmpty {
                        ContentUnavailableView(
                            "Nothing logged yet",
                            systemImage: "fork.knife",
                            description: Text("Use the camera button to photograph a meal, or the pencil to type one.")
                        )
                    } else {
                        ForEach(todaysEntries) { entry in
                            EntryRow(entry: entry)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle(Date.now.formatted(date: .abbreviated, time: .omitted))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingManual = true
                    } label: {
                        Label("Add by text", systemImage: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPhoto = true
                    } label: {
                        Label("Add from photo", systemImage: "camera")
                    }
                }
            }
        }
        .sheet(isPresented: $showingPhoto) {
            PhotoAnalysisView().environmentObject(settings)
        }
        .sheet(isPresented: $showingManual) {
            ManualEntryView().environmentObject(settings)
        }
        .onAppear(perform: refreshKeyState)
        .onChange(of: settings.provider) { _, _ in refreshKeyState() }
        .onChange(of: showingPhoto) { _, _ in refreshKeyState() }
    }

    private func refreshKeyState() {
        hasKey = KeychainStore.hasKey(account: settings.provider.keychainAccount)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(todaysEntries[index])
        }
        try? context.save()
    }
}

/// Shared by Today and History.
struct EntryRow: View {

    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                    .lineLimit(1)
                Text(
                    entry.date.formatted(date: .omitted, time: .shortened)
                    + " · " + entry.source.label
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 2) {
                Text("\(Int(entry.totals.calories.rounded()))")
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = entry.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: entry.source.systemImage)
                        .foregroundStyle(.secondary)
                )
        }
    }
}
