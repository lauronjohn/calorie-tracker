import SwiftUI

/// Calories consumed against the daily goal.
struct CalorieRingView: View {

    let consumed: Double
    let goal: Double

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return max(consumed / goal, 0)
    }

    private var remaining: Double { goal - consumed }

    private var tint: Color {
        fraction > 1 ? .orange : .accentColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 18)

            // A second lap is drawn on top once you pass the goal, so going over is
            // visible rather than just pinning at full.
            Circle()
                .trim(from: 0, to: min(fraction, 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if fraction > 1 {
                Circle()
                    .trim(from: 0, to: min(fraction - 1, 1))
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text("\(Int(consumed.rounded()))")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("of \(Int(goal.rounded())) kcal")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(remaining >= 0
                     ? "\(Int(remaining.rounded())) left"
                     : "\(Int(abs(remaining).rounded())) over")
                    .font(.caption)
                    .foregroundStyle(remaining >= 0 ? .secondary : .red)
                    .padding(.top, 2)
            }
        }
        .animation(.easeOut(duration: 0.35), value: fraction)
        .frame(width: 200, height: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories")
        .accessibilityValue("\(Int(consumed.rounded())) of \(Int(goal.rounded())) kilocalories")
    }
}

/// Protein / carbs / fat progress against their goals.
struct MacroBarsView: View {

    let totals: MacroTotals
    let goals: MacroTotals

    var body: some View {
        VStack(spacing: 10) {
            bar("Protein", totals.protein, goals.protein, .pink)
            bar("Carbs", totals.carbs, goals.carbs, .teal)
            bar("Fat", totals.fat, goals.fat, .yellow)
        }
    }

    private func bar(_ label: String, _ value: Double, _ goal: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(value.rounded())) / \(Int(goal.rounded())) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: goal > 0 ? min(value / goal, 1) : 0)
                .tint(color)
        }
    }
}
