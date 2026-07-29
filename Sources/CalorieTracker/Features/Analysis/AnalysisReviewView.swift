import SwiftUI
import SwiftData

/// Editable copy of an analysed item. The model's numbers are estimates, so nothing
/// reaches the log without passing through this screen.
private struct EditableItem: Identifiable {
    let id = UUID()
    var name: String
    var portion: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var confidence: Confidence

    init(_ item: AnalyzedItem) {
        name = item.name
        portion = item.portion
        calories = item.calories
        proteinG = item.proteinG
        carbsG = item.carbsG
        fatG = item.fatG
        confidence = item.confidence
    }

    init() {
        name = ""
        portion = ""
        calories = 0
        proteinG = 0
        carbsG = 0
        fatG = 0
        confidence = .medium
    }

    var asFoodItem: FoodItem {
        FoodItem(
            name: name.isEmpty ? "Untitled" : name,
            portion: portion,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            confidence: confidence
        )
    }
}

struct AnalysisReviewView: View {

    let result: AnalysisResult
    let imageData: Data?
    let source: EntrySource
    var onSaved: () -> Void

    @Environment(\.modelContext) private var context

    @State private var items: [EditableItem]
    @State private var note: String

    init(
        result: AnalysisResult,
        imageData: Data? = nil,
        source: EntrySource,
        onSaved: @escaping () -> Void
    ) {
        self.result = result
        self.imageData = imageData
        self.source = source
        self.onSaved = onSaved
        _items = State(initialValue: result.items.map(EditableItem.init))
        _note = State(initialValue: result.note)
    }

    private var totals: MacroTotals {
        MacroTotals(
            calories: items.reduce(0) { $0 + $1.calories },
            protein: items.reduce(0) { $0 + $1.proteinG },
            carbs: items.reduce(0) { $0 + $1.carbsG },
            fat: items.reduce(0) { $0 + $1.fatG }
        )
    }

    var body: some View {
        Form {
            Section {
                MacroSummaryRow(totals: totals)
            } header: {
                Text("Total")
            } footer: {
                Text("Totals are added up on your phone from the items below — edit any number and this updates.")
            }

            ForEach($items) { $item in
                Section {
                    TextField("Name", text: $item.name)
                    TextField("Portion", text: $item.portion)
                    LabeledNumberField(label: "Calories", unit: "kcal", value: $item.calories)
                    LabeledNumberField(label: "Protein", unit: "g", value: $item.proteinG)
                    LabeledNumberField(label: "Carbs", unit: "g", value: $item.carbsG)
                    LabeledNumberField(label: "Fat", unit: "g", value: $item.fatG)
                    Picker("Confidence", selection: $item.confidence) {
                        ForEach(Confidence.allCases) { Text($0.label).tag($0) }
                    }

                    // Each item is its own Section, and swipe-to-delete only applies
                    // to rows — hence an explicit button rather than `.onDelete`.
                    Button("Remove item", role: .destructive) {
                        let id = item.id
                        items.removeAll { $0.id == id }
                    }
                } header: {
                    HStack {
                        Text(item.name.isEmpty ? "Item" : item.name)
                        Spacer()
                        ConfidenceBadge(confidence: item.confidence)
                    }
                }
            }

            Section {
                Button {
                    items.append(EditableItem())
                } label: {
                    Label("Add item", systemImage: "plus")
                }
            }

            if !result.assumptions.isEmpty {
                Section("What this assumed") {
                    ForEach(result.assumptions, id: \.self) { assumption in
                        Label(assumption, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Note") {
                TextField("Optional", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(items.isEmpty)
            }
        }
    }

    private func save() {
        let entry = FoodEntry(
            date: .now,
            source: source,
            note: note,
            imageData: imageData,
            items: items.map(\.asFoodItem)
        )
        context.insert(entry)
        try? context.save()
        onSaved()
    }
}

// MARK: - Small pieces

private struct LabeledNumberField: View {
    let label: String
    let unit: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Confidence

    private var color: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    var body: some View {
        Text(confidence.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct MacroSummaryRow: View {
    let totals: MacroTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Int(totals.calories.rounded())) kcal")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(
                "P \(Int(totals.protein.rounded()))g · "
                + "C \(Int(totals.carbs.rounded()))g · "
                + "F \(Int(totals.fat.rounded()))g"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}
