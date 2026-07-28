import Foundation
import SwiftData

/// Where an entry came from. Kept for display and for judging how much to trust the numbers.
enum EntrySource: String, Codable {
    case photo
    case manual

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .manual: return "Typed"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: return "camera"
        case .manual: return "pencil"
        }
    }
}

/// A single logged meal.
@Model
final class FoodEntry {
    var date: Date
    /// Stored as a `String` because SwiftData does not persist enums directly.
    var sourceRaw: String
    var note: String
    /// Downscaled JPEG of the analysed photo, if there was one.
    @Attribute(.externalStorage) var imageData: Data?

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.entry)
    var items: [FoodItem]

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        source: EntrySource,
        note: String = "",
        imageData: Data? = nil,
        items: [FoodItem] = []
    ) {
        self.date = date
        self.sourceRaw = source.rawValue
        self.note = note
        self.imageData = imageData
        self.items = items
    }

    /// A short human label for the meal, derived from its items.
    var title: String {
        switch items.count {
        case 0: return "Empty entry"
        case 1: return items[0].name
        case 2: return "\(items[0].name) + \(items[1].name)"
        default: return "\(items[0].name) + \(items.count - 1) more"
        }
    }
}

// MARK: - Totals

extension FoodEntry: NutritionCarrying {
    var loggedAt: Date { date }
    var totals: MacroTotals { MacroTotals(items) }
}
