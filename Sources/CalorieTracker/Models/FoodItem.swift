import Foundation
import SwiftData

/// How confident the model was about a single item's estimate.
enum Confidence: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/// One food on a plate. A `FoodEntry` is a meal; a `FoodItem` is a component of it.
@Model
final class FoodItem {
    var name: String
    var portion: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    /// Stored as a `String` because SwiftData does not persist enums directly.
    var confidenceRaw: String

    var entry: FoodEntry?

    var confidence: Confidence {
        get { Confidence(rawValue: confidenceRaw) ?? .medium }
        set { confidenceRaw = newValue.rawValue }
    }

    init(
        name: String,
        portion: String = "",
        calories: Double,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        confidence: Confidence = .medium
    ) {
        self.name = name
        self.portion = portion
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.confidenceRaw = confidence.rawValue
    }
}
