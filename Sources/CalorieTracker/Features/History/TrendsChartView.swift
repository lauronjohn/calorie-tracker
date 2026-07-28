import SwiftUI
import Charts

enum TrendRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30

    var id: Int { rawValue }
    var label: String { self == .week ? "7 days" : "30 days" }
}

struct TrendsChartView: View {

    let points: [DayPoint]
    let goal: Double

    private var average: Double {
        guard !points.isEmpty else { return 0 }
        return points.reduce(0) { $0 + $1.totals.calories } / Double(points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(average.rounded())) kcal/day")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }

            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Day", point.day, unit: .day),
                        y: .value("Calories", point.totals.calories)
                    )
                    .foregroundStyle(point.totals.calories > goal ? Color.orange : Color.accentColor)
                }

                if goal > 0 {
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
        }
    }
}
