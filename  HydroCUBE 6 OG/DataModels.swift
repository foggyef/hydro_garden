import Foundation
import SwiftUI

// Represents a single point for environment controls (e.g., light intensity at a time)
struct Point: Codable {
    let hour: Int      // 0–23
    let minute: Int    // 0–59
    let intensity: Double  // e.g., 0.0 to 100.0
}

// Represents an environment profile for JSON storage
struct CodableEnvironmentProfile: Codable {
    let title: String
    let lightValue: Double
    let fanInValue: Double
    let fanOutValue: Double
    let bubblerValue: Double
    let humidifierValue: Double
    let lightStartHour: Int
    let lightStartMinute: Int
    let fanInStartHour: Int
    let fanInStartMinute: Int
    let fanOutStartHour: Int
    let fanOutStartMinute: Int
    let bubblerStartHour: Int
    let bubblerStartMinute: Int
    let humidifierStartHour: Int
    let humidifierStartMinute: Int
    let lightEndHour: Int
    let lightEndMinute: Int
    let fanInEndHour: Int
    let fanInEndMinute: Int
    let fanOutEndHour: Int
    let fanOutEndMinute: Int
    let bubblerEndHour: Int
    let bubblerEndMinute: Int
    let humidifierEndHour: Int
    let humidifierEndMinute: Int
    let lightConstant: Bool
    let fanInConstant: Bool
    let fanOutConstant: Bool
    let bubblerConstant: Bool
    let humidifierConstant: Bool
    let lightSliderColor: String // e.g., "purple"
    let fanInSliderColor: String
    let fanOutSliderColor: String
    let bubblerSliderColor: String
    let humidifierSliderColor: String
    let lightPoints: [Point]
    let fanInPoints: [Point]
    let fanOutPoints: [Point]
    let bubblerPoints: [Point]
    let humidifierPoints: [Point]
    let lightMode: String
    let fanInMode: String
    let fanOutMode: String
    let bubblerMode: String
    let humidifierMode: String
}

// Represents a single nutrient for JSON storage
struct CodableNutrient: Codable {
    let name: String
    let grams: Double
    let color: String // e.g., "blue"
}

// Represents a nutrient profile for JSON storage
struct CodableNutrientProfile: Codable {
    let title: String
    let nutrients: [CodableNutrient]
    let baseOunces: Double
}
