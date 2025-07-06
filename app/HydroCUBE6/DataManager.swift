import Foundation
import SwiftUI

func loadEnvironmentProfiles() -> [CodableEnvironmentProfile] {
    let fileManager = FileManager.default
    var allProfiles: [CodableEnvironmentProfile] = []
    
    // Load user profiles from documents directory
    if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = documentsURL.appendingPathComponent("userEnvironmentProfiles.json")
        if fileManager.fileExists(atPath: fileURL.path) {
            print("Checking user profiles at: \(fileURL.path)")
            do {
                let data = try Data(contentsOf: fileURL)
                print("User profiles data loaded, size: \(data.count) bytes")
                let profiles = try JSONDecoder().decode([CodableEnvironmentProfile].self, from: data)
                allProfiles.append(contentsOf: profiles)
                print("Loaded user profiles: \(profiles.map { $0.title })")
            } catch {
                print("Failed to load user environment profiles: \(error)")
            }
        } else {
            print("No user profiles file found, attempting to load from bundle")
        }
    } else {
        print("Failed to access documents directory")
    }
    
    // Load bundle profiles
    guard let url = Bundle.main.url(forResource: "environmentProfiles", withExtension: "json") else {
        print("Failed to locate environmentProfiles.json in bundle. Ensure the file is added to the target and 'Copy Bundle Resources' in Build Phases.")
        // Fallback profile
        let fallbackProfile = CodableEnvironmentProfile(
            title: "Fallback Profile",
            lightValue: 50.0,
            fanInValue: 35.0,
            fanOutValue: 35.0,
            bubblerValue: 25.0,
            humidifierValue: 65.0,
            lightStartHour: 0,
            lightStartMinute: 0,
            fanInStartHour: 0,
            fanInStartMinute: 0,
            fanOutStartHour: 0,
            fanOutStartMinute: 0,
            bubblerStartHour: 0,
            bubblerStartMinute: 0,
            humidifierStartHour: 0,
            humidifierStartMinute: 0,
            lightEndHour: 0,
            lightEndMinute: 0,
            fanInEndHour: 0,
            fanInEndMinute: 0,
            fanOutEndHour: 0,
            fanOutEndMinute: 0,
            bubblerEndHour: 0,
            bubblerEndMinute: 0,
            humidifierEndHour: 0,
            humidifierEndMinute: 0,
            lightConstant: false,
            fanInConstant: false,
            fanOutConstant: false,
            bubblerConstant: true,
            humidifierConstant: false,
            lightSliderColor: "purple",
            fanInSliderColor: "blue",
            fanOutSliderColor: "red",
            bubblerSliderColor: "green",
            humidifierSliderColor: "orange",
            lightPoints: [],
            fanInPoints: [],
            fanOutPoints: [],
            bubblerPoints: [],
            humidifierPoints: [],
            lightMode: "slider",
            fanInMode: "slider",
            fanOutMode: "slider",
            bubblerMode: "slider",
            humidifierMode: "slider"
        )
        print("Returning fallback profile: \(fallbackProfile.title)")
        return allProfiles.isEmpty ? [fallbackProfile] : allProfiles
    }
    
    do {
        print("Attempting to load from bundle at: \(url.path)")
        let data = try Data(contentsOf: url)
        print("Bundle profiles data loaded, size: \(data.count) bytes")
        let decoder = JSONDecoder()
        let bundleProfiles = try decoder.decode([CodableEnvironmentProfile].self, from: data)
        // Add bundle profiles, avoiding duplicates
        allProfiles.append(contentsOf: bundleProfiles.filter { bundleProfile in
            !allProfiles.contains { $0.title == bundleProfile.title }
        })
        print("Loaded bundle profiles: \(bundleProfiles.map { $0.title })")
    } catch {
        print("Failed to decode environment profiles: \(error)")
        // Fallback profile
        let fallbackProfile = CodableEnvironmentProfile(
            title: "Fallback Profile",
            lightValue: 50.0,
            fanInValue: 35.0,
            fanOutValue: 35.0,
            bubblerValue: 25.0,
            humidifierValue: 65.0,
            lightStartHour: 0,
            lightStartMinute: 0,
            fanInStartHour: 0,
            fanInStartMinute: 0,
            fanOutStartHour: 0,
            fanOutStartMinute: 0,
            bubblerStartHour: 0,
            bubblerStartMinute: 0,
            humidifierStartHour: 0,
            humidifierStartMinute: 0,
            lightEndHour: 0,
            lightEndMinute: 0,
            fanInEndHour: 0,
            fanInEndMinute: 0,
            fanOutEndHour: 0,
            fanOutEndMinute: 0,
            bubblerEndHour: 0,
            bubblerEndMinute: 0,
            humidifierEndHour: 0,
            humidifierEndMinute: 0,
            lightConstant: false,
            fanInConstant: false,
            fanOutConstant: false,
            bubblerConstant: true,
            humidifierConstant: false,
            lightSliderColor: "purple",
            fanInSliderColor: "blue",
            fanOutSliderColor: "red",
            bubblerSliderColor: "green",
            humidifierSliderColor: "orange",
            lightPoints: [],
            fanInPoints: [],
            fanOutPoints: [],
            bubblerPoints: [],
            humidifierPoints: [],
            lightMode: "slider",
            fanInMode: "slider",
            fanOutMode: "slider",
            bubblerMode: "slider",
            humidifierMode: "slider"
        )
        print("Returning fallback profile: \(fallbackProfile.title)")
        if allProfiles.isEmpty {
            allProfiles.append(fallbackProfile)
        }
    }
    
    return allProfiles
}
func loadNutrientProfiles() -> [CodableNutrientProfile] {
    let fileManager = FileManager.default
    if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = documentsURL.appendingPathComponent("userNutrientProfiles.json")
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                return try decoder.decode([CodableNutrientProfile].self, from: data)
            } catch {
                print("Failed to load user nutrient profiles: \(error)")
            }
        }
    }
    
    guard let url = Bundle.main.url(forResource: "nutrientProfiles", withExtension: "json"),
          let data = try? Data(contentsOf: url) else {
        print("Failed to load nutrientProfiles.json from bundle")
        return []
    }
    do {
        let decoder = JSONDecoder()
        return try decoder.decode([CodableNutrientProfile].self, from: data)
    } catch {
        print("Failed to decode nutrient profiles: \(error)")
        return []
    }
}

func saveEnvironmentProfiles(profiles: [EnvironmentProfile]) {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let fileURL = documentsURL.appendingPathComponent("userEnvironmentProfiles.json")

    let codableProfiles = profiles.map { profile in
        CodableEnvironmentProfile(
            title: profile.title,
            lightValue: profile.lightValue,
            fanInValue: profile.fanInValue,
            fanOutValue: profile.fanOutValue,
            bubblerValue: profile.bubblerValue,
            humidifierValue: profile.humidifierValue,
            lightStartHour: Calendar.current.component(.hour, from: profile.lightStart),
            lightStartMinute: Calendar.current.component(.minute, from: profile.lightStart),
            fanInStartHour: Calendar.current.component(.hour, from: profile.fanInStart),
            fanInStartMinute: Calendar.current.component(.minute, from: profile.fanInStart),
            fanOutStartHour: Calendar.current.component(.hour, from: profile.fanOutStart),
            fanOutStartMinute: Calendar.current.component(.minute, from: profile.fanOutStart),
            bubblerStartHour: Calendar.current.component(.hour, from: profile.bubblerStart),
            bubblerStartMinute: Calendar.current.component(.minute, from: profile.bubblerStart),
            humidifierStartHour: Calendar.current.component(.hour, from: profile.humidifierStart),
            humidifierStartMinute: Calendar.current.component(.minute, from: profile.humidifierStart),
            lightEndHour: Calendar.current.component(.hour, from: profile.lightEnd),
            lightEndMinute: Calendar.current.component(.minute, from: profile.lightEnd),
            fanInEndHour: Calendar.current.component(.hour, from: profile.fanInEnd),
            fanInEndMinute: Calendar.current.component(.minute, from: profile.fanInEnd),
            fanOutEndHour: Calendar.current.component(.hour, from: profile.fanOutEnd),
            fanOutEndMinute: Calendar.current.component(.minute, from: profile.fanOutEnd),
            bubblerEndHour: Calendar.current.component(.hour, from: profile.bubblerEnd),
            bubblerEndMinute: Calendar.current.component(.minute, from: profile.bubblerEnd),
            humidifierEndHour: Calendar.current.component(.hour, from: profile.humidifierEnd),
            humidifierEndMinute: Calendar.current.component(.minute, from: profile.humidifierEnd),
            lightConstant: profile.lightConstant,
            fanInConstant: profile.fanInConstant,
            fanOutConstant: profile.fanOutConstant,
            bubblerConstant: profile.bubblerConstant,
            humidifierConstant: profile.humidifierConstant,
            lightSliderColor: stringFromColor(profile.lightSliderColor),
            fanInSliderColor: stringFromColor(profile.fanInSliderColor),
            fanOutSliderColor: stringFromColor(profile.fanOutSliderColor),
            bubblerSliderColor: stringFromColor(profile.bubblerSliderColor),
            humidifierSliderColor: stringFromColor(profile.humidifierSliderColor),
            lightPoints: profile.lightPoints.map { point in
                let components = Calendar.current.dateComponents([.hour, .minute], from: point.time)
                return Point(hour: components.hour ?? 0, minute: components.minute ?? 0, intensity: point.intensity)
            },
            fanInPoints: profile.fanInPoints.map { point in
                let components = Calendar.current.dateComponents([.hour, .minute], from: point.time)
                return Point(hour: components.hour ?? 0, minute: components.minute ?? 0, intensity: point.intensity)
            },
            fanOutPoints: profile.fanOutPoints.map { point in
                let components = Calendar.current.dateComponents([.hour, .minute], from: point.time)
                return Point(hour: components.hour ?? 0, minute: components.minute ?? 0, intensity: point.intensity)
            },
            bubblerPoints: profile.bubblerPoints.map { point in
                let components = Calendar.current.dateComponents([.hour, .minute], from: point.time)
                return Point(hour: components.hour ?? 0, minute: components.minute ?? 0, intensity: point.intensity)
            },
            humidifierPoints: profile.humidifierPoints.map { point in
                let components = Calendar.current.dateComponents([.hour, .minute], from: point.time)
                return Point(hour: components.hour ?? 0, minute: components.minute ?? 0, intensity: point.intensity)
            },
            lightMode: profile.lightMode,
            fanInMode: profile.fanInMode,
            fanOutMode: profile.fanOutMode,
            bubblerMode: profile.bubblerMode,
            humidifierMode: profile.humidifierMode
        )
    }

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(codableProfiles)
        try data.write(to: fileURL)
        print("Saved user profiles: \(codableProfiles.map { $0.title })")
    } catch {
        print("Failed to save environment profiles: \(error)")
    }
}

func saveNutrientProfiles(profiles: [NutrientProfile]) {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let fileURL = documentsURL.appendingPathComponent("userNutrientProfiles.json")

    let codableProfiles = profiles.map { profile in
        CodableNutrientProfile(
            title: profile.title,
            nutrients: profile.nutrients.map { nutrient in
                CodableNutrient(name: nutrient.name, grams: nutrient.grams, color: stringFromColor(nutrient.color))
            },
            baseOunces: profile.baseOunces
        )
    }

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(codableProfiles)
        try data.write(to: fileURL)
    } catch {
        print("Failed to save nutrient profiles: \(error)")
    }
}

// Helper functions for color conversion
func colorFromString(_ colorString: String) -> Color {
    switch colorString.lowercased() {
    case "blue": return .blue
    case "red": return .red
    case "green": return .green
    case "purple": return .purple
    case "orange": return .orange
    case "pink": return .pink
    case "cyan": return .cyan
    case "yellow": return .yellow
    case "brown": return .brown
    case "teal": return .teal
    default: return .gray
    }
}

func stringFromColor(_ color: Color) -> String {
    switch color.description.lowercased() {
    case Color.blue.description: return "blue"
    case Color.red.description: return "red"
    case Color.green.description: return "green"
    case Color.purple.description: return "purple"
    case Color.orange.description: return "orange"
    case Color.pink.description: return "pink"
    case Color.cyan.description: return "cyan"
    case Color.yellow.description: return "yellow"
    case Color.brown.description: return "brown"
    case Color.teal.description: return "teal"
    default: return "gray"
    }
}
