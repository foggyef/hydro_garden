import SwiftUI
import Foundation

// EnvironmentProfile struct
struct EnvironmentProfile {
    var title: String
    var lightValue: Double
    var fanInValue: Double
    var fanOutValue: Double
    var bubblerValue: Double
    var humidifierValue: Double
    var lightStart: Date
    var fanInStart: Date
    var fanOutStart: Date
    var bubblerStart: Date
    var humidifierStart: Date
    var lightEnd: Date
    var fanInEnd: Date
    var fanOutEnd: Date
    var bubblerEnd: Date
    var humidifierEnd: Date
    var lightConstant: Bool
    var fanInConstant: Bool
    var fanOutConstant: Bool
    var bubblerConstant: Bool
    var humidifierConstant: Bool
    var lightSliderColor: Color
    var fanInSliderColor: Color
    var fanOutSliderColor: Color
    var bubblerSliderColor: Color
    var humidifierSliderColor: Color
    var lightPoints: [(time: Date, intensity: Double, color: Color)]
    var fanInPoints: [(time: Date, intensity: Double, color: Color)]
    var fanOutPoints: [(time: Date, intensity: Double, color: Color)]
    var bubblerPoints: [(time: Date, intensity: Double, color: Color)]
    var humidifierPoints: [(time: Date, intensity: Double, color: Color)]
    var lightMode: String
    var fanInMode: String
    var fanOutMode: String
    var bubblerMode: String
    var humidifierMode: String
}

// Nutrient struct
struct Nutrient: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var grams: Double
    let color: Color
}

// NutrientProfile struct
struct NutrientProfile {
    var title: String
    var nutrients: [Nutrient]
    var baseOunces: Double
}
