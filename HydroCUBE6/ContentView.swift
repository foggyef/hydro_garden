import SwiftUI
import Foundation
import Charts
import CoreBluetooth

// Enum to manage focus states for nutrient fields
enum FocusedField: Hashable {
    case name(UUID)
    case grams(UUID)
}

// MARK: - Supporting Structs

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let percentage: Double
    let type: String
}

enum AlertType: Identifiable {
    case environmentDelete
    case nutrientDelete
    case selectEnvironment
    case confirmProceedWithoutNutrient
    
    var id: Int {
        switch self {
        case .environmentDelete: return 1
        case .nutrientDelete: return 2
        case .selectEnvironment: return 3
        case .confirmProceedWithoutNutrient: return 4
        }
    }
}

struct SeparatorLine: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.gray)
    }
}

struct DarkeningButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let backgroundOpacity: Double
        if configuration.isPressed {
            backgroundOpacity = 0.9
        } else if isActive {
            backgroundOpacity = 0.7
        } else {
            backgroundOpacity = 0.1
        }
        let textColor: Color = (configuration.isPressed || isActive) ? .white : .blue

        return configuration.label
            .font(.system(size: 16))
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(backgroundOpacity))
            .cornerRadius(5)
    }
}

struct BluetoothDeviceListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var showingSheet: Bool
    
    var body: some View {
        NavigationView {
            List(bluetoothManager.discoveredPeripherals, id: \.identifier) { peripheral in
                Button(action: {
                    bluetoothManager.connect(to: peripheral)
                    showingSheet = false
                }) {
                    Text(peripheral.name ?? "Unknown Device")
                }
            }
            .navigationTitle("Select a Device")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        bluetoothManager.stopScanning()
                        showingSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    // State variables for environment controls
    @State private var fanInValue = 0.0
    @State private var fanOutValue = 0.0
    @State private var bubblerValue = 0.0
    @State private var lightValue = 0.0
    @State private var humidifierValue = 0.0
    @State private var fanInStart = Date()
    @State private var fanOutStart = Date()
    @State private var bubblerStart = Date()
    @State private var lightStart = Date()
    @State private var humidifierStart = Date()
    @State private var fanInEnd = Date()
    @State private var fanOutEnd = Date()
    @State private var bubblerEnd = Date()
    @State private var lightEnd = Date()
    @State private var humidifierEnd = Date()
    @State private var fanInConstant = false
    @State private var fanOutConstant = false
    @State private var bubblerConstant = false
    @State private var lightConstant = false
    @State private var humidifierConstant = false
    @State private var fanInSliderColor: Color = .blue
    @State private var fanOutSliderColor: Color = .red
    @State private var bubblerSliderColor: Color = .green
    @State private var lightSliderColor: Color = .purple
    @State private var humidifierSliderColor: Color = .orange
    @State private var scrollToSection: String? = nil
    
    // Mode state for each control
    @State private var lightMode: String = "slider"
    @State private var fanInMode: String = "slider"
    @State private var fanOutMode: String = "slider"
    @State private var bubblerMode: String = "slider"
    @State private var humidifierMode: String = "slider"
    
    // Function parameters for each control with added 'n' for frequency (number of peaks)
    @State private var functionParams: [String: (a: Double, b: Double, c: Double, k: Double, n: Int)] = [
        "Light": (a: 1.0, b: 1.0, c: 0.0, k: 2.0, n: 1),
        "Fan In": (a: 0.8, b: 1.0, c: -2.0, k: 2.0, n: 1),
        "Fan Out": (a: 0.7, b: 1.0, c: 2.0, k: 2.0, n: 1),
        "Bubbler": (a: 0.9, b: 1.0, c: 0.0, k: 2.0, n: 1),
        "Humidifier": (a: 0.6, b: 1.0, c: -1.0, k: 2.0, n: 1)
    ]
    
    @State private var expandedSection: String? = nil
    @State private var selectedSlider: String? = nil
    @State private var appTitle = "HydroCUBE"
    @State private var isEditingTitle = false
    @State private var userInput = ""
    
    @State private var showingTimePicker = false
    @State private var showingPercentagePicker = false
    @State private var selectedTimeBinding: Binding<Date>?
    @State private var selectedPercentageBinding: Binding<Double>?
    @State private var selectedTab: String = "Environment"
    
    @State private var editingControl: String? = nil
    
    @State private var expandedNutrient: String? = nil
    
    @State private var chartType: String = "Environment"
    
    @State private var isLongPressing = false
    @State private var startTime: Date?
    @GestureState private var dragTranslation: CGFloat = 0
    
    @FocusState private var focusedField: FocusedField?
    
    @State private var isEditingEnvironment = false
    
    // New state variable to enable editing in "Start grow" mode
    @State private var isEditingEnvironmentControls = false
    
    @State private var activeAlert: AlertType? = nil
    
    @State private var environmentProfiles: [EnvironmentProfile] = []
    @State private var environmentTypes: [String] = ["Load Environment"]
    @State private var selectedEnvironment = "Load Environment"
    @State private var showNewEnvironment = false
    @State private var newEnvironmentTitle = ""
    @State private var hasMadeEnvironmentEdits = false
    
    @State private var nutrientProfiles: [NutrientProfile] = []
    @State private var selectedNutrientType = "What are you growing"
    @State private var nutrientTypes = ["What are you growing"]
    @State private var selectedAmount = "1 gallon"
    let amounts = [
        "Mixing size",
        "8 OZ",
        "16 OZ",
        "32 OZ",
        "64 OZ",
        "1 gallon"
    ]
    @State private var showNewNutrientProfile = false
    @State private var newNutrientTitle = ""
    @State private var newNutrients: [Nutrient] = [Nutrient(name: "", grams: 0.0, color: .black)]
    @State private var hasMadeNutrientEdits = false
    @State private var isEditingNutrientProfile = false
    @State private var npkTitle: String = "Default"
    
    @State private var isTestingGrow = false
    @State private var animationProgress: Double = 0
    @State private var testGrowTimer: Timer? = nil
    
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showingBluetoothSheet = false
    @State private var showBluetoothAlert = false
    
    @State private var showConnectionMessage = false
    @State private var connectionMessage = ""
    
    static let nutrientColors: [Color] = [.blue, .red, .green, .purple, .orange, .yellow, .brown, .teal]
    
    @AppStorage("growStartDate") private var growStartDate: Double = 0
    
    private var growDays: Int {
        let now = Date()
        if growStartDate == 0 {
            return 0
        } else {
            let startDate = Date(timeIntervalSinceReferenceDate: growStartDate)
            return Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 0
        }
    }
    
    private var currentTime: Date {
        if isTestingGrow {
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let totalSeconds = endOfDay.timeIntervalSince(startOfDay)
            return startOfDay.addingTimeInterval(animationProgress * totalSeconds)
        } else {
            return Date()
        }
    }
    
    private var graphData: [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        
        func generateSliderPoints(start: Date, end: Date, value: Double, constant: Bool, type: String) -> [ChartDataPoint] {
            let calendar = Calendar.current
            let now = currentTime
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            if constant {
                return [
                    ChartDataPoint(time: startOfDay, percentage: value, type: type),
                    ChartDataPoint(time: endOfDay, percentage: value, type: type)
                ]
            } else {
                let timeStep: TimeInterval = 900 // 15 minutes
                var times: [Date] = []
                var currentTime = startOfDay
                while currentTime <= endOfDay {
                    times.append(currentTime)
                    currentTime = calendar.date(byAdding: .second, value: Int(timeStep), to: currentTime)!
                }
                if !times.contains(start) {
                    times.append(start)
                }
                if !times.contains(end) {
                    times.append(end)
                }
                times = times.sorted()
                
                var points: [ChartDataPoint] = []
                for time in times {
                    let isActive: Bool
                    if start <= end {
                        isActive = time >= start && time <= end
                    } else {
                        isActive = time <= end || time >= start
                    }
                    let percentage = isActive ? value : 0.0
                    points.append(ChartDataPoint(time: time, percentage: percentage, type: type))
                }
                return points
            }
        }
        
        func generateFunctionPoints(for control: String) -> [ChartDataPoint] {
            guard let params = functionParams[control], params.b != 0, params.k >= 0.5, params.n >= 1 else { return [] }
            let a = params.a
            let b = params.b
            let c = params.c
            let k = params.k
            let n = params.n
            let f = Double(n) / 48.0 // Frequency: n peaks over 24 hours
            
            let calendar = Calendar.current
            let now = currentTime
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let totalSeconds = endOfDay.timeIntervalSince(startOfDay)
            
            let step = 60.0 // Every minute
            var points: [ChartDataPoint] = []
            for t in stride(from: 0, to: totalSeconds, by: step) {
                let time = startOfDay.addingTimeInterval(t)
                let x = (t / totalSeconds) * 24 - 12 // Map to -12 to 12 hours
                let theta = 2 * Double.pi * f * (x - c)
                let term = sin(theta) / b
                let yRaw = a * 100 * exp(-pow(abs(term), k))
                let y = max(yRaw, 0)
                points.append(ChartDataPoint(time: time, percentage: y, type: control))
            }
            return points
        }
        
        if lightMode == "function" {
            data.append(contentsOf: generateFunctionPoints(for: "Light"))
        } else {
            data.append(contentsOf: generateSliderPoints(start: lightStart, end: lightEnd, value: lightValue, constant: lightConstant, type: "Light"))
        }
        
        if fanInMode == "function" {
            data.append(contentsOf: generateFunctionPoints(for: "Fan In"))
        } else {
            data.append(contentsOf: generateSliderPoints(start: fanInStart, end: fanInEnd, value: fanInValue, constant: fanInConstant, type: "Fan In"))
        }
        
        if fanOutMode == "function" {
            data.append(contentsOf: generateFunctionPoints(for: "Fan Out"))
        } else {
            data.append(contentsOf: generateSliderPoints(start: fanOutStart, end: fanOutEnd, value: fanOutValue, constant: fanOutConstant, type: "Fan Out"))
        }
        
        if bubblerMode == "function" {
            data.append(contentsOf: generateFunctionPoints(for: "Bubbler"))
        } else {
            data.append(contentsOf: generateSliderPoints(start: bubblerStart, end: bubblerEnd, value: bubblerValue, constant: bubblerConstant, type: "Bubbler"))
        }
        
        if humidifierMode == "function" {
            data.append(contentsOf: generateFunctionPoints(for: "Humidifier"))
        } else {
            data.append(contentsOf: generateSliderPoints(start: humidifierStart, end: humidifierEnd, value: humidifierValue, constant: humidifierConstant, type: "Humidifier"))
        }
        
        return data.sorted { $0.time < $1.time }
    }
    
    init() {
        let loadedEnvProfiles = loadEnvironmentProfiles()
        print("Loaded environment profiles: \(loadedEnvProfiles.map { $0.title })")
        _environmentProfiles = State(initialValue: convertToEnvironmentProfiles(loadedEnvProfiles))
        let profileTitles = loadedEnvProfiles.map { $0.title }
        _environmentTypes = State(initialValue: ["Load Environment"] + profileTitles)
        print("Environment types initialized: \(_environmentTypes.wrappedValue)")
        
        let loadedNutrientProfiles = loadNutrientProfiles()
        _nutrientProfiles = State(initialValue: convertToNutrientProfiles(loadedNutrientProfiles))
        _nutrientTypes = State(initialValue: ["What are you growing"] + loadedNutrientProfiles.map { $0.title })
        print("Nutrient types initialized: \(_nutrientTypes.wrappedValue)")
        
#if DEBUG
        UserDefaults.standard.removeObject(forKey: "growStartDate")
#endif
    }
    
    private func startTestGrowAnimation() {
        isTestingGrow = true
        animationProgress = 0
        let totalDuration: TimeInterval = 10.0
        let interval: TimeInterval = 0.1
        let steps = Int(totalDuration / interval)
        var currentStep = 0
        
        testGrowTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            animationProgress = Double(currentStep) / Double(steps)
            if currentStep >= steps {
                timer.invalidate()
                testGrowTimer = nil
                isTestingGrow = false
                animationProgress = 0
            }
        }
    }
    
    private func convertToEnvironmentProfiles(_ profiles: [CodableEnvironmentProfile]) -> [EnvironmentProfile] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        func dateFromHourMinute(hour: Int, minute: Int) -> Date {
            var components = calendar.dateComponents([.year, .month, .day], from: startOfDay)
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components) ?? startOfDay
        }
        
        return profiles.map { profile in
            EnvironmentProfile(
                title: profile.title,
                lightValue: profile.lightValue,
                fanInValue: profile.fanInValue,
                fanOutValue: profile.fanOutValue,
                bubblerValue: profile.bubblerValue,
                humidifierValue: profile.humidifierValue,
                lightStart: dateFromHourMinute(hour: profile.lightStartHour, minute: profile.lightStartMinute),
                fanInStart: dateFromHourMinute(hour: profile.fanInStartHour, minute: profile.fanInStartMinute),
                fanOutStart: dateFromHourMinute(hour: profile.fanOutStartHour, minute: profile.fanOutStartMinute),
                bubblerStart: dateFromHourMinute(hour: profile.bubblerStartHour, minute: profile.bubblerStartMinute),
                humidifierStart: dateFromHourMinute(hour: profile.humidifierStartHour, minute: profile.humidifierStartMinute),
                lightEnd: dateFromHourMinute(hour: profile.lightEndHour, minute: profile.lightEndMinute),
                fanInEnd: dateFromHourMinute(hour: profile.fanInEndHour, minute: profile.fanInEndMinute),
                fanOutEnd: dateFromHourMinute(hour: profile.fanOutEndHour, minute: profile.fanOutEndMinute),
                bubblerEnd: dateFromHourMinute(hour: profile.bubblerEndHour, minute: profile.bubblerEndMinute),
                humidifierEnd: dateFromHourMinute(hour: profile.humidifierEndHour, minute: profile.humidifierEndMinute),
                lightConstant: profile.lightConstant,
                fanInConstant: profile.fanInConstant,
                fanOutConstant: profile.fanOutConstant,
                bubblerConstant: profile.bubblerConstant,
                humidifierConstant: profile.humidifierConstant,
                lightSliderColor: colorFromString(profile.lightSliderColor),
                fanInSliderColor: colorFromString(profile.fanInSliderColor),
                fanOutSliderColor: colorFromString(profile.fanOutSliderColor),
                bubblerSliderColor: colorFromString(profile.bubblerSliderColor),
                humidifierSliderColor: colorFromString(profile.humidifierSliderColor),
                lightPoints: [],
                fanInPoints: [],
                fanOutPoints: [],
                bubblerPoints: [],
                humidifierPoints: [],
                lightMode: profile.lightMode == "points" ? "slider" : profile.lightMode,
                fanInMode: profile.fanInMode == "points" ? "slider" : profile.fanInMode,
                fanOutMode: profile.fanOutMode == "points" ? "slider" : profile.fanOutMode,
                bubblerMode: profile.bubblerMode == "points" ? "slider" : profile.bubblerMode,
                humidifierMode: profile.humidifierMode == "points" ? "slider" : profile.humidifierMode
            )
        }
    }
    
    private func convertToNutrientProfiles(_ profiles: [CodableNutrientProfile]) -> [NutrientProfile] {
        return profiles.map { profile in
            NutrientProfile(
                title: profile.title,
                nutrients: profile.nutrients.map { nutrient in
                    Nutrient(name: nutrient.name, grams: nutrient.grams, color: colorFromString(nutrient.color))
                },
                baseOunces: profile.baseOunces
            )
        }
    }
    
    private func deleteSelectedEnvironmentProfile() {
        if let index = environmentProfiles.firstIndex(where: { $0.title == selectedEnvironment }) {
            environmentProfiles.remove(at: index)
            environmentTypes.removeAll { $0 == selectedEnvironment }
            saveEnvironmentProfiles(profiles: environmentProfiles)
        }
        selectedEnvironment = "Load Environment"
        isEditingEnvironment = false
        showNewEnvironment = false
        newEnvironmentTitle = ""
        hasMadeEnvironmentEdits = false
    }
    
    private func deleteSelectedNutrientProfile() {
        if let index = nutrientProfiles.firstIndex(where: { $0.title == selectedNutrientType }) {
            nutrientProfiles.remove(at: index)
            nutrientTypes.removeAll { $0 == selectedNutrientType }
            saveNutrientProfiles(profiles: nutrientProfiles)
        }
        selectedNutrientType = "What are you growing"
        showNewNutrientProfile = false
        isEditingNutrientProfile = false
        newNutrientTitle = ""
        newNutrients = [Nutrient(name: "", grams: 0.0, color: Self.nutrientColors[0])]
        hasMadeNutrientEdits = false
    }
    
    private func calculateNutrientAmounts(for amount: String, profile: NutrientProfile) -> ([Nutrient], Double, Double) {
        var selectedOunces: Double = 0.0
        if amount != "Mixing size" {
            let components = amount.split(separator: " ")
            if components.count == 2, let number = Double(components[0]) {
                let unitType = components[1].lowercased()
                selectedOunces = unitType == "oz" ? number : (unitType == "gallon" ? number * 128.0 : 0.0)
            }
        }
        if selectedOunces == 0.0 {
            selectedOunces = profile.baseOunces
        }
        let factor = selectedOunces / profile.baseOunces
        let scaledNutrients = profile.nutrients.map { nutrient in
            Nutrient(name: nutrient.name, grams: nutrient.grams * factor, color: nutrient.color)
        }
        let totalGrams = scaledNutrients.reduce(0.0) { $0 + $1.grams }
        return (scaledNutrients, totalGrams, 0.0)
    }
    
    private func formatPercentage(_ value: Double) -> String {
        return String(format: "%.0f%%", value)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    chartView()
                        .frame(height: 220)
                        .padding(.horizontal, 16)
                    
                    EnvironmentTabView(selectedTab: $selectedTab)
                        .padding(.bottom, 20)
                    
                    if selectedTab == "Environment" {
                        ScrollViewReader { proxy in
                            ScrollView {
                                controlPanel()
                                feedbackSection()
                            }
                            .padding(.horizontal, 16)
                            .onChange(of: scrollToSection) { oldValue, newValue in
                                if let section = newValue {
                                    withAnimation {
                                        proxy.scrollTo(section, anchor: .init(x: 0.5, y: 0.0))
                                    }
                                }
                            }
                        }
                    } else if selectedTab == "Nutrients" {
                        nutrientsSection()
                            .padding(.horizontal, 16)
                    }
                    
                    if showConnectionMessage {
                        Text(connectionMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                            .transition(.opacity)
                    }
                }
                .navigationTitle(appTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { isEditingTitle = true }) {
                            Image(systemName: "arrow.backward")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if bluetoothManager.connectedPeripheral == nil {
                            Button(action: {
                                if bluetoothManager.centralManager.state == .poweredOn {
                                    showingBluetoothSheet = true
                                    bluetoothManager.startScanning()
                                } else {
                                    showBluetoothAlert = true
                                }
                            }) {
                                Text("Connect")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(5)
                            }
                        } else {
                            Button(action: {
                                bluetoothManager.disconnect()
                            }) {
                                Text("Disconnect")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(5)
                            }
                        }
                    }
                }
                .foregroundColor(.black)
                .onTapGesture {
                    withAnimation {
                        expandedSection = nil
                        selectedSlider = nil
                    }
                }
                .sheet(isPresented: $showingTimePicker) {
                    if let binding = selectedTimeBinding {
                        VStack {
                            DatePicker("Select Time", selection: binding, displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                            Button("Done") { showingTimePicker = false }
                                .padding()
                        }
                        .presentationDetents([.medium])
                    }
                }
                .sheet(isPresented: $showingPercentagePicker) {
                    if let binding = selectedPercentageBinding {
                        VStack {
                            Picker("Select Percentage", selection: binding) {
                                ForEach(0...100, id: \.self) { value in
                                    Text("\(value)%").tag(Double(value))
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        .presentationDetents([.medium])
                    }
                }
                .sheet(isPresented: $showingBluetoothSheet) {
                    BluetoothDeviceListView(bluetoothManager: bluetoothManager, showingSheet: $showingBluetoothSheet)
                }
                .alert(isPresented: $showBluetoothAlert) {
                    Alert(title: Text("Bluetooth Required"), message: Text("Please enable Bluetooth in Settings."), dismissButton: .default(Text("OK")))
                }
                .onChange(of: selectedTab) { oldValue, newValue in
                    withAnimation {
                        chartType = newValue
                    }
                }
                .onChange(of: bluetoothManager.connectionState) { oldValue, newValue in
                    switch newValue {
                    case .connecting:
                        connectionMessage = "Connecting..."
                        showConnectionMessage = true
                    case .connected:
                        if let peripheral = bluetoothManager.connectedPeripheral {
                            connectionMessage = "Connected to \(peripheral.name ?? "Unknown Device")"
                        } else {
                            connectionMessage = "Connected"
                        }
                        showConnectionMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showConnectionMessage = false
                        }
                    case .failed:
                        connectionMessage = "Connection failed"
                        showConnectionMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showConnectionMessage = false
                            bluetoothManager.connectionState = .idle
                        }
                    case .idle:
                        if oldValue == .connected {
                            connectionMessage = "Disconnected"
                            showConnectionMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showConnectionMessage = false
                            }
                        }
                    }
                }
                .alert(item: $activeAlert) { alertType in
                    switch alertType {
                    case .environmentDelete:
                        return Alert(
                            title: Text("Delete Environment Profile"),
                            message: Text("Are you sure you want to delete this environment profile?"),
                            primaryButton: .destructive(Text("Yes")) {
                                deleteSelectedEnvironmentProfile()
                            },
                            secondaryButton: .cancel(Text("No"))
                        )
                    case .nutrientDelete:
                        return Alert(
                            title: Text("Delete Nutrient Profile"),
                            message: Text("Are you sure you want to delete this nutrient profile?"),
                            primaryButton: .destructive(Text("Yes")) { deleteSelectedNutrientProfile() },
                            secondaryButton: .cancel(Text("No"))
                        )
                    case .selectEnvironment:
                        return Alert(
                            title: Text("Select Environment"),
                            message: Text("Please select an environment before starting the grow."),
                            dismissButton: .default(Text("OK"))
                        )
                    case .confirmProceedWithoutNutrient:
                        return Alert(
                            title: Text("No Nutrient Profile Selected"),
                            message: Text("Would you like to proceed without selecting a nutrient profile?"),
                            primaryButton: .default(Text("Proceed")) {
                                growStartDate = Date().timeIntervalSinceReferenceDate
                                print("Proceeded without nutrient profile, start date set to \(growStartDate)")
                            },
                            secondaryButton: .cancel(Text("Cancel"))
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func chartView() -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let baseOffset: CGFloat = chartType == "Environment" ? 0 : -width
            
            HStack(spacing: 0) {
                let calendar = Calendar.current
                let now = currentTime
                let startOfDay = calendar.startOfDay(for: now)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let chartContent = Chart {
                    ForEach(graphData) { dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.time),
                            y: .value("Percentage", dataPoint.percentage)
                        )
                        .foregroundStyle(by: .value("Type", dataPoint.type))
                        .opacity(selectedSlider == nil || selectedSlider == dataPoint.type ? 1.0 : 0.3)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    
                    RuleMark(x: .value("Current Time", now))
                        .foregroundStyle(Color.black)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    
                    if isTestingGrow {
                        let totalSeconds = endOfDay.timeIntervalSince(startOfDay)
                        let simulatedTime = startOfDay.addingTimeInterval(animationProgress * totalSeconds)
                        RuleMark(x: .value("Simulated Time", simulatedTime))
                            .foregroundStyle(Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                
                chartContent
                    .chartForegroundStyleScale([
                        "Fan In": fanInSliderColor,
                        "Fan Out": fanOutSliderColor,
                        "Bubbler": bubblerSliderColor,
                        "Light": lightSliderColor,
                        "Humidifier": humidifierSliderColor
                    ])
                    .chartXScale(domain: startOfDay...endOfDay)
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                                .foregroundStyle(Color.black)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(Int(doubleValue))%")
                                        .foregroundStyle(Color.black)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .frame(width: width, height: 200)
                    .background(Color.white)
                    .padding(.vertical, 10)
                
                if selectedNutrientType != "What are you growing",
                   let profile = nutrientProfiles.first(where: { $0.title == selectedNutrientType }) {
                    let (nutrients, _, _) = calculateNutrientAmounts(for: selectedAmount, profile: profile)
                    
                    if !nutrients.isEmpty {
                        let maxLabelLength = 8
                        let chartData = nutrients.map { nutrient in
                            let shortName = nutrient.name.count > maxLabelLength
                            ? String(nutrient.name.prefix(maxLabelLength - 3) + "...")
                            : nutrient.name
                            return (label: shortName, fullName: nutrient.name, grams: nutrient.grams, color: nutrient.color)
                        }
                        
                        Chart {
                            ForEach(chartData, id: \.fullName) { data in
                                BarMark(
                                    x: .value("Nutrient", data.label),
                                    y: .value("Grams", data.grams)
                                )
                                .foregroundStyle(data.color)
                                .cornerRadius(4)
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel()
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(String(format: "%.2f g", doubleValue))
                                            .foregroundStyle(.black)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .frame(width: width, height: 200)
                        .background(Color.white)
                        .padding(.vertical, 10)
                        .overlay(
                            Group {
                                if let selectedNutrient = expandedNutrient,
                                   let data = chartData.first(where: { $0.fullName == selectedNutrient }) {
                                    let barIndex = chartData.firstIndex { $0.fullName == selectedNutrient } ?? 0
                                    let barCount = chartData.count
                                    let barWidth = geometry.size.width / CGFloat(barCount)
                                    let barCenterX = barWidth * CGFloat(barIndex) + barWidth / 2
                                    let annotationWidth: CGFloat = 150
                                    let halfAnnotationWidth = annotationWidth / 2
                                    let minX = halfAnnotationWidth
                                    let maxX = geometry.size.width - halfAnnotationWidth
                                    let xPosition = min(max(barCenterX, minX), maxX)
                                    let maxGrams = chartData.map { $0.grams }.max() ?? 1
                                    let yPosition = geometry.size.height * (1 - (data.grams / maxGrams)) - 20
                                    let clampedYPosition = max(yPosition, 20)
                                    
                                    Text(data.fullName)
                                        .font(.caption)
                                        .foregroundColor(.black)
                                        .padding(8)
                                        .background(Color.white.opacity(0.9))
                                        .cornerRadius(6)
                                        .shadow(radius: 3)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: annotationWidth)
                                        .position(x: xPosition, y: clampedYPosition)
                                        .zIndex(1)
                                        .transition(.opacity)
                                }
                            }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if startTime == nil {
                                        startTime = Date()
                                    }
                                    let timeElapsed = Date().timeIntervalSince(startTime!)
                                    let translation = value.translation.width
                                    if !isLongPressing && timeElapsed >= 0.5 && abs(translation) < 10 {
                                        isLongPressing = true
                                        let touchX = value.location.x
                                        let barCount = chartData.count
                                        let barWidth = geometry.size.width / CGFloat(barCount)
                                        let barIndex = Int(touchX / barWidth)
                                        if barIndex >= 0 && barIndex < chartData.count {
                                            withAnimation {
                                                expandedNutrient = chartData[barIndex].fullName
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    isLongPressing = false
                                    startTime = nil
                                    withAnimation {
                                        expandedNutrient = nil
                                    }
                                }
                        )
                    } else {
                        Text("No nutrient data available")
                            .foregroundColor(.gray)
                            .frame(width: width, height: 200)
                            .background(Color.white)
                            .padding(.vertical, 10)
                    }
                } else {
                    Text("Select a nutrient profile")
                        .foregroundColor(.gray)
                        .frame(width: width, height: 200)
                        .background(Color.white)
                        .padding(.vertical, 10)
                }
            }
            .offset(x: baseOffset + dragTranslation)
            .simultaneousGesture(
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if chartType == "Environment" && translation < -50 {
                                chartType = "Nutrients"
                            } else if chartType == "Nutrients" && translation > 50 {
                                chartType = "Environment"
                            }
                        }
                    }
            )
        }
        .frame(height: 220)
        .clipped()
    }
    
    @ViewBuilder
    private func environmentSelectionView() -> some View {
        if growStartDate != 0 && selectedEnvironment != "Load Environment" {
            HStack {
                Text(selectedEnvironment)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.leading, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 20) {
                if growStartDate == 0 {
                    if isEditingEnvironment {
                        Button(action: {
                            activeAlert = .environmentDelete
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 20))
                        }
                    }
                    
                    if !isEditingEnvironment && !showNewEnvironment && selectedEnvironment != "Load Environment" {
                        Button(action: {
                            newEnvironmentTitle = selectedEnvironment
                            isEditingEnvironment = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(4)
                        }
                    }
                }
                
                if showNewEnvironment || isEditingEnvironment {
                    TextField(
                        showNewEnvironment ? "Enter Environment Title" : "Edit Environment Title",
                        text: $newEnvironmentTitle
                    )
                    .font(.body)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .tint(.black)
                    .onChange(of: newEnvironmentTitle) { oldValue, newValue in
                        hasMadeEnvironmentEdits = !newValue.isEmpty
                    }
                } else {
                    Menu {
                        ForEach(environmentTypes.filter { $0 != "Load Environment" }, id: \.self) { type in
                            Button(type) {
                                if isTestingGrow {
                                    testGrowTimer?.invalidate()
                                    testGrowTimer = nil
                                    isTestingGrow = false
                                    animationProgress = 0
                                }
                                selectedEnvironment = type
                                if let profile = environmentProfiles.first(where: { $0.title == type }) {
                                    lightValue = profile.lightValue
                                    fanInValue = profile.fanInValue
                                    fanOutValue = profile.fanOutValue
                                    bubblerValue = profile.bubblerValue
                                    humidifierValue = profile.humidifierValue
                                    lightStart = profile.lightStart
                                    fanInStart = profile.fanInStart
                                    fanOutStart = profile.fanOutStart
                                    bubblerStart = profile.bubblerStart
                                    humidifierStart = profile.humidifierStart
                                    lightEnd = profile.lightEnd
                                    fanInEnd = profile.fanInEnd
                                    fanOutEnd = profile.fanOutEnd
                                    bubblerEnd = profile.bubblerEnd
                                    humidifierEnd = profile.humidifierEnd
                                    lightConstant = profile.lightConstant
                                    fanInConstant = profile.fanInConstant
                                    fanOutConstant = profile.fanOutConstant
                                    bubblerConstant = profile.bubblerConstant
                                    humidifierConstant = profile.humidifierConstant
                                    lightSliderColor = profile.lightSliderColor
                                    fanInSliderColor = profile.fanInSliderColor
                                    fanOutSliderColor = profile.fanOutSliderColor
                                    bubblerSliderColor = profile.bubblerSliderColor
                                    humidifierSliderColor = profile.humidifierSliderColor
                                    lightMode = profile.lightMode
                                    fanInMode = profile.fanInMode
                                    fanOutMode = profile.fanOutMode
                                    bubblerMode = profile.bubblerMode
                                    humidifierMode = profile.humidifierMode
                                }
                                isEditingEnvironment = false
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedEnvironment)
                                .font(.body)
                                .foregroundColor(selectedEnvironment == "Load Environment" ? .gray : .black)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    }
                }
                
                if growStartDate == 0 {
                    if isEditingEnvironment {
                        Button(action: {
                            if hasMadeEnvironmentEdits {
                                let newTitle = newEnvironmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                if let index = environmentProfiles.firstIndex(where: { $0.title == selectedEnvironment }) {
                                    let originalTitle = selectedEnvironment
                                    if !newTitle.isEmpty && (newTitle == originalTitle || !environmentProfiles.contains(where: { $0.title == newTitle })) {
                                        var updatedProfile = environmentProfiles[index]
                                        updatedProfile.title = newTitle
                                        environmentProfiles[index] = updatedProfile
                                        if let typeIndex = environmentTypes.firstIndex(of: originalTitle) {
                                            environmentTypes[typeIndex] = newTitle
                                        }
                                        selectedEnvironment = newTitle
                                        saveEnvironmentProfiles(profiles: environmentProfiles)
                                    } else {
                                        print("Title is empty or already exists.")
                                    }
                                }
                            }
                            isEditingEnvironment = false
                            newEnvironmentTitle = ""
                            hasMadeEnvironmentEdits = false
                        }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.system(size: 25, weight: .light))
                        }
                    } else {
                        Button(action: {
                            if showNewEnvironment {
                                if hasMadeEnvironmentEdits {
                                    let newTitle = newEnvironmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !newTitle.isEmpty && !environmentProfiles.contains(where: { $0.title == newTitle }) {
                                        if environmentProfiles.count < 10 {
                                            let newProfile = EnvironmentProfile(
                                                title: newTitle,
                                                lightValue: lightValue,
                                                fanInValue: fanInValue,
                                                fanOutValue: fanOutValue,
                                                bubblerValue: bubblerValue,
                                                humidifierValue: humidifierValue,
                                                lightStart: lightStart,
                                                fanInStart: fanInStart,
                                                fanOutStart: fanOutStart,
                                                bubblerStart: bubblerStart,
                                                humidifierStart: humidifierStart,
                                                lightEnd: lightEnd,
                                                fanInEnd: fanInEnd,
                                                fanOutEnd: fanOutEnd,
                                                bubblerEnd: bubblerEnd,
                                                humidifierEnd: humidifierEnd,
                                                lightConstant: lightConstant,
                                                fanInConstant: fanInConstant,
                                                fanOutConstant: fanOutConstant,
                                                bubblerConstant: bubblerConstant,
                                                humidifierConstant: humidifierConstant,
                                                lightSliderColor: lightSliderColor,
                                                fanInSliderColor: fanInSliderColor,
                                                fanOutSliderColor: fanOutSliderColor,
                                                bubblerSliderColor: bubblerSliderColor,
                                                humidifierSliderColor: humidifierSliderColor,
                                                lightPoints: [],
                                                fanInPoints: [],
                                                fanOutPoints: [],
                                                bubblerPoints: [],
                                                humidifierPoints: [],
                                                lightMode: lightMode,
                                                fanInMode: fanInMode,
                                                fanOutMode: fanOutMode,
                                                bubblerMode: bubblerMode,
                                                humidifierMode: humidifierMode
                                            )
                                            environmentProfiles.append(newProfile)
                                            environmentTypes.append(newTitle)
                                            selectedEnvironment = newTitle
                                            saveEnvironmentProfiles(profiles: environmentProfiles)
                                        } else {
                                            print("Maximum of 10 environment profiles reached.")
                                        }
                                    }
                                }
                                showNewEnvironment = false
                                newEnvironmentTitle = ""
                                hasMadeEnvironmentEdits = false
                            } else {
                                showNewEnvironment = true
                                newEnvironmentTitle = ""
                                hasMadeEnvironmentEdits = false
                            }
                        }) {
                            Image(systemName: showNewEnvironment ? (hasMadeEnvironmentEdits ? "checkmark" : "xmark") : "plus")
                                .foregroundColor(.blue)
                                .font(.system(size: 25, weight: .light))
                        }
                        .disabled(growStartDate != 0 || (!showNewEnvironment && environmentProfiles.count >= 10))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func controlRowsView() -> some View {
        makeControlRow(
            title: "Light",
            value: lightMode == "slider" ? $lightValue : nil,
            start: lightMode == "slider" ? $lightStart : nil,
            end: lightMode == "slider" ? $lightEnd : nil,
            constant: lightMode == "slider" ? $lightConstant : nil,
            color: lightMode == "slider" ? lightSliderColor : nil,
            colorBinding: $lightSliderColor,
            mode: $lightMode
        )
        makeControlRow(
            title: "Fan In",
            value: fanInMode == "slider" ? $fanInValue : nil,
            start: fanInMode == "slider" ? $fanInStart : nil,
            end: fanInMode == "slider" ? $fanInEnd : nil,
            constant: fanInMode == "slider" ? $fanInConstant : nil,
            color: fanInMode == "slider" ? fanInSliderColor : nil,
            colorBinding: $fanInSliderColor,
            mode: $fanInMode
        )
        makeControlRow(
            title: "Fan Out",
            value: fanOutMode == "slider" ? $fanOutValue : nil,
            start: fanOutMode == "slider" ? $fanOutStart : nil,
            end: fanOutMode == "slider" ? $fanOutEnd : nil,
            constant: fanOutMode == "slider" ? $fanOutConstant : nil,
            color: fanOutMode == "slider" ? fanOutSliderColor : nil,
            colorBinding: $fanOutSliderColor,
            mode: $fanOutMode
        )
        makeControlRow(
            title: "Bubbler",
            value: bubblerMode == "slider" ? $bubblerValue : nil,
            start: bubblerMode == "slider" ? $bubblerStart : nil,
            end: bubblerMode == "slider" ? $bubblerEnd : nil,
            constant: bubblerMode == "slider" ? $bubblerConstant : nil,
            color: bubblerMode == "slider" ? bubblerSliderColor : nil,
            colorBinding: $bubblerSliderColor,
            mode: $bubblerMode
        )
        makeControlRow(
            title: "Humidifier",
            value: humidifierMode == "slider" ? $humidifierValue : nil,
            start: humidifierMode == "slider" ? $humidifierStart : nil,
            end: humidifierMode == "slider" ? $humidifierEnd : nil,
            constant: humidifierMode == "slider" ? $humidifierConstant : nil,
            color: humidifierMode == "slider" ? humidifierSliderColor : nil,
            colorBinding: $humidifierSliderColor,
            mode: $humidifierMode
        )
    }
    
    @ViewBuilder
    private func controlPanel() -> some View {
        VStack(spacing: 20) {
            environmentSelectionView()
            controlsSeparator()
            controlRowsView()
        }
    }
    
    @ViewBuilder
    private func feedbackSection() -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $userInput)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .border(Color.gray.opacity(0.3), width: 1)
                .shadow(color: Color.white.opacity(0.3), radius: 1, x: -1, y: -1)
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 1, y: 1)
                .tint(.black)
            
            if userInput.isEmpty {
                Text("Feedback")
                    .foregroundColor(Color.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            }
        }
        .frame(height: 100)
        .overlay(
            Button(action: {
                print("Submitted: \(userInput)")
                userInput = ""
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.blue)
                    .padding(10)
            },
            alignment: .bottomTrailing
        )
        .padding()
    }
    
    @ViewBuilder
    private func nutrientsSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            nutrientsSectionTitleView()
            if showNewNutrientProfile {
                nutrientFieldsView()
            } else if selectedNutrientType != "What are you growing" {
                nutrientProfileDisplayView()
            }
        }
    }
    
    @ViewBuilder
    private func controlsSeparator() -> some View {
        ZStack(alignment: .center) {
            Divider()
                .foregroundColor(.gray)
            
            HStack {
                Text("\(growDays) \(growDays == 1 ? "Day" : "Days")")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.leading, 16)
                    .background(Color.white)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button(action: {
                        if growStartDate == 0 {
                            if selectedEnvironment == "Load Environment" {
                                activeAlert = .selectEnvironment
                            } else if selectedNutrientType == "What are you growing" {
                                activeAlert = .confirmProceedWithoutNutrient
                            } else {
                                growStartDate = Date().timeIntervalSinceReferenceDate
                                editingControl = nil
                                print("Start pressed, start date set to \(growStartDate)")
                            }
                        } else {
                            growStartDate = 0
                            isEditingEnvironmentControls = false
                            print("Stop pressed, start date reset to 0")
                        }
                    }) {
                        Text(growStartDate == 0 ? "Start" : "Stop")
                    }
                    .buttonStyle(DarkeningButtonStyle(isActive: growStartDate != 0))
                    
                    Button(action: {
                        startTestGrowAnimation()
                    }) {
                        Text("Preview")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .disabled(isTestingGrow)
                    
                    if growStartDate != 0 {
                        Button(action: {
                            isEditingEnvironmentControls.toggle()
                        }) {
                            Text(isEditingEnvironmentControls ? "Done" : "Edit")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(5)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    @ViewBuilder
    private func nutrientsSectionTitleView() -> some View {
        if growStartDate != 0 && selectedNutrientType != "What are you growing" {
            HStack {
                Text(selectedNutrientType)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.leading, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 10) {
                if isEditingNutrientProfile {
                    Button(action: {
                        activeAlert = .nutrientDelete
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                    }
                }
                
                if showNewNutrientProfile {
                    TextField("Enter Nutrient Profile Title", text: $newNutrientTitle)
                        .font(.body)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .tint(.black)
                        .onChange(of: newNutrientTitle) { oldValue, newValue in
                            if isEditingNutrientProfile, let profile = nutrientProfiles.first(where: { $0.title == selectedNutrientType }) {
                                hasMadeNutrientEdits = newValue != profile.title || newNutrients != profile.nutrients
                            } else {
                                hasMadeNutrientEdits = !newValue.isEmpty || newNutrients.contains { !$0.name.isEmpty || $0.grams > 0 }
                            }
                        }
                } else {
                    Menu {
                        ForEach(nutrientTypes.filter { $0 != "What are you growing" }, id: \.self) { type in
                            Button(type) {
                                selectedNutrientType = type
                                showNewNutrientProfile = false
                                npkTitle = type
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedNutrientType)
                                .font(.body)
                                .foregroundColor(selectedNutrientType == "What are you growing" ? .gray : .black)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    }
                }
                
                Menu {
                    ForEach(amounts.filter { $0 != "Mixing size" }, id: \.self) { amount in
                        Button(amount) {
                            selectedAmount = amount
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedAmount)
                            .font(.body)
                            .foregroundColor(selectedAmount == "OZ" ? .gray : .black)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical)
                    .frame(minWidth: 80)
                    .frame(height: 54)
                    .background(Color.white)
                    .cornerRadius(0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                
                nutrientsSectionButtons()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func nutrientsSectionButtons() -> some View {
        HStack(spacing: 20) {
            if selectedNutrientType != "What are you growing" && !showNewNutrientProfile {
                Button(action: {
                    if let profile = nutrientProfiles.first(where: { $0.title == selectedNutrientType }) {
                        showNewNutrientProfile = true
                        isEditingNutrientProfile = true
                        newNutrientTitle = profile.title
                        let nextColorIndex = profile.nutrients.count % Self.nutrientColors.count
                        newNutrients = profile.nutrients.map { Nutrient(name: $0.name, grams: $0.grams, color: $0.color) } +
                            [Nutrient(name: "", grams: 0.0, color: Self.nutrientColors[nextColorIndex])]
                        hasMadeNutrientEdits = false
                    }
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(4)
                }
            }
            
            if showNewNutrientProfile {
                Button(action: {
                    if hasMadeNutrientEdits {
                        let validNutrients = newNutrients.filter { !$0.name.isEmpty && $0.grams >= 0 }
                        var baseOunces: Double = 128.0
                        if selectedAmount != "Mixing size" {
                            let components = selectedAmount.split(separator: " ")
                            if components.count == 2, let number = Double(components[0]) {
                                let unitType = components[1].lowercased()
                                baseOunces = unitType == "oz" ? number : number * 128.0
                            }
                        }
                        if !newNutrientTitle.isEmpty && !validNutrients.isEmpty {
                            let newProfile = NutrientProfile(title: newNutrientTitle, nutrients: validNutrients, baseOunces: baseOunces)
                            if isEditingNutrientProfile {
                                if let index = nutrientProfiles.firstIndex(where: { $0.title == selectedNutrientType }) {
                                    if newNutrientTitle != selectedNutrientType && nutrientProfiles.contains(where: { $0.title == newNutrientTitle }) {
                                        print("A profile with this title already exists.")
                                    } else {
                                        nutrientProfiles[index] = newProfile
                                        if let typeIndex = nutrientTypes.firstIndex(of: selectedNutrientType) {
                                            nutrientTypes[typeIndex] = newNutrientTitle
                                        }
                                        selectedNutrientType = newNutrientTitle
                                        npkTitle = newNutrientTitle
                                    }
                                }
                            } else if nutrientProfiles.count < 10 {
                                if !nutrientProfiles.contains(where: { $0.title == newNutrientTitle }) {
                                    nutrientProfiles.append(newProfile)
                                    nutrientTypes.append(newNutrientTitle)
                                    selectedNutrientType = newNutrientTitle
                                    npkTitle = newNutrientTitle
                                } else {
                                    print("A profile with this title already exists.")
                                }
                            } else {
                                print("Maximum of 10 nutrient profiles reached.")
                            }
                            saveNutrientProfiles(profiles: nutrientProfiles)
                        }
                    }
                    showNewNutrientProfile = false
                    isEditingNutrientProfile = false
                    newNutrientTitle = ""
                    newNutrients = [Nutrient(name: "", grams: 0.0, color: Self.nutrientColors[0])]
                    hasMadeNutrientEdits = false
                }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 25, weight: .light))
                }
            }
            
            if !showNewNutrientProfile {
                Button(action: {
                    selectedNutrientType = "What are you growing"
                    showNewNutrientProfile = true
                    isEditingNutrientProfile = false
                    newNutrientTitle = ""
                    newNutrients = [Nutrient(name: "", grams: 0.0, color: Self.nutrientColors[0])]
                    hasMadeNutrientEdits = false
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                        .font(.system(size: 25, weight: .light))
                }
                .disabled(nutrientProfiles.count >= 10)
            }
        }
    }
    
    @ViewBuilder
    private func nutrientFieldsView() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            nutrientFieldsList()
        }
    }
    
    @ViewBuilder
    private func nutrientFieldsList() -> some View {
        ForEach(newNutrients.indices, id: \.self) { index in
            nutrientFieldRow(index: index)
        }
    }
    
    @ViewBuilder
    private func nutrientFieldRow(index: Int) -> some View {
        let nutrient = newNutrients[index]
        HStack {
            TextField("Nutrient Name", text: Binding(
                get: { nutrient.name },
                set: { newValue in
                    newNutrients[index].name = newValue
                    updateNutrientsAfterChange(at: index)
                }
            ))
            .focused($focusedField, equals: .name(nutrient.id))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(maxWidth: 200)
            .foregroundColor(nutrient.color)
            .tint(.black)
            
            TextField("grams", text: Binding(
                get: { nutrient.grams == 0.0 ? "" : String(nutrient.grams) },
                set: { newValue in
                    if let value = Double(newValue) {
                        newNutrients[index].grams = value
                        updateNutrientsAfterChange(at: index)
                    } else if newValue.isEmpty {
                        newNutrients[index].grams = 0.0
                    }
                }
            ))
            .focused($focusedField, equals: .grams(nutrient.id))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 80)
            .keyboardType(.decimalPad)
            .tint(.black)
        }
        .id(nutrient.id)
    }
    
    private func updateNutrientsAfterChange(at index: Int) {
        if newNutrients[index].name.isEmpty && index < newNutrients.count - 1 {
            let nonEmptyNutrients = newNutrients[0...index].filter { !$0.name.isEmpty }
            let nextColorIndex = nonEmptyNutrients.count % Self.nutrientColors.count
            newNutrients = Array(nonEmptyNutrients) + [Nutrient(name: "", grams: 0.0, color: Self.nutrientColors[nextColorIndex])]
        } else if index == newNutrients.count - 1 && !newNutrients[index].name.isEmpty && newNutrients.count < 8 {
            let nextColorIndex = newNutrients.count % Self.nutrientColors.count
            newNutrients.append(Nutrient(name: "", grams: 0.0, color: Self.nutrientColors[nextColorIndex]))
        }
        updateHasMadeNutrientEdits()
    }
    
    private func updateHasMadeNutrientEdits() {
        if isEditingNutrientProfile, let profile = nutrientProfiles.first(where: { $0.title == selectedNutrientType }) {
            hasMadeNutrientEdits = newNutrientTitle != profile.title || newNutrients != profile.nutrients
        } else {
            hasMadeNutrientEdits = !newNutrientTitle.isEmpty || newNutrients.contains { !$0.name.isEmpty || $0.grams > 0 }
        }
    }
    
    @ViewBuilder
    private func nutrientProfileDisplayView() -> some View {
        if let profile = nutrientProfiles.first(where: { $0.title == selectedNutrientType }) {
            let (nutrients, _, _) = calculateNutrientAmounts(for: selectedAmount, profile: profile)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(nutrients) { nutrient in
                    HStack(spacing: 5) {
                        Text(nutrient.name)
                            .fontWeight(.semibold)
                            .foregroundColor(nutrient.color)
                        Text("\(String(format: "%.2f", nutrient.grams)) grams")
                            .frame(height: 32)
                    }
                }
            }
            .padding(.leading, 16)
        }
    }
    
    @ViewBuilder
    private func makeControlRow(
        title: String,
        value: Binding<Double>? = nil,
        start: Binding<Date>? = nil,
        end: Binding<Date>? = nil,
        constant: Binding<Bool>? = nil,
        color: Color? = nil,
        colorBinding: Binding<Color>,
        mode: Binding<String>
    ) -> some View {
        VStack(spacing: 10) {
            summaryRow(
                title: title,
                constant: constant,
                start: start,
                end: end,
                isExpanded: expandedSection == title,
                colorBinding: colorBinding,
                mode: mode
            )
            
            if expandedSection == title {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.gray, Color.clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.vertical, 5)
                
                if mode.wrappedValue == "function" {
                    functionModeControls(
                        title: title,
                        functionParams: Binding(
                            get: { functionParams[title] ?? (a: 1.0, b: 10.0, c: 0.0, k: 2.0, n: 1) },
                            set: { functionParams[title] = $0 }
                        )
                    )
                } else {
                    simpleModeControls(
                        title: title,
                        value: value,
                        color: color,
                        colorBinding: colorBinding,
                        start: start,
                        end: end,
                        constant: constant
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .border(Color.gray.opacity(0.3), width: 1)
        .shadow(color: Color.white.opacity(0.3), radius: 1, x: -1, y: -1)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 1, y: 1)
        .onTapGesture {
            withAnimation {
                if expandedSection == title {
                    expandedSection = nil
                    editingControl = nil
                } else {
                    expandedSection = title
                    scrollToSection = title
                }
                selectedSlider = title
            }
        }
        .id(title)
    }
    
    @ViewBuilder
    private func summaryRow(
        title: String,
        constant: Binding<Bool>?,
        start: Binding<Date>?,
        end: Binding<Date>?,
        isExpanded: Bool,
        colorBinding: Binding<Color>,
        mode: Binding<String>
    ) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.black)
            
            if isExpanded && (growStartDate == 0 || isEditingEnvironmentControls) {
                HStack(spacing: 10) {
                    Button(action: {
                        if mode.wrappedValue != "slider" {
                            mode.wrappedValue = "slider"
                            if editingControl == title {
                                editingControl = nil
                            }
                        }
                    }) {
                        Text("Slider")
                            .font(.system(size: 14))
                            .foregroundColor(mode.wrappedValue == "slider" ? .white : .blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(mode.wrappedValue == "slider" ? Color.blue : Color.clear)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        if mode.wrappedValue != "function" {
                            mode.wrappedValue = "function"
                            if editingControl == title {
                                editingControl = nil
                            }
                        }
                    }) {
                        Text("Function")
                            .font(.system(size: 14))
                            .foregroundColor(mode.wrappedValue == "function" ? .white : .blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(mode.wrappedValue == "function" ? Color.blue : Color.clear)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                }
                .padding(.leading, 10)
            }
            
            Spacer()
            
            if !isExpanded {
                if let constant = constant, let start = start, let end = end {
                    if constant.wrappedValue {
                        Text("24/7")
                            .font(.system(size: 17))
                            .foregroundColor(.green)
                    } else {
                        Text("\(formatTime(start.wrappedValue))-\(formatTime(end.wrappedValue))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func simpleModeControls(
        title: String,
        value: Binding<Double>?,
        color: Color?,
        colorBinding: Binding<Color>?,
        start: Binding<Date>?,
        end: Binding<Date>?,
        constant: Binding<Bool>?
    ) -> some View {
        if let value = value, let color = color, let start = start, let end = end, let constant = constant {
            HStack {
                if title == "Light", let colorBinding = colorBinding {
                    ColorPicker("", selection: colorBinding)
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                        .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
                }
                Slider(value: value, in: 1...100, step: 1)
                    .tint(color)
                    .frame(maxWidth: .infinity)
                    .onChange(of: value.wrappedValue) { oldValue, newValue in
                        selectedSlider = title
                    }
                    .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
                Text(formatPercentage(value.wrappedValue))
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.leading, 10)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                timePickerRow(start: start, end: end, constant: constant)
            }
            .padding(.top, 5)
        }
    }
    
    @ViewBuilder
    private func timePickerRow(
        start: Binding<Date>,
        end: Binding<Date>,
        constant: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            if growStartDate == 0 || isEditingEnvironmentControls {
                Text(formatTime(start.wrappedValue))
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .frame(width: 100, height: 30)
                    .background(Color.white)
                    .cornerRadius(4)
                    .onTapGesture {
                        selectedTimeBinding = start
                        showingTimePicker = true
                    }
            } else {
                Text(formatTime(start.wrappedValue))
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .frame(width: 100, height: 30)
                    .background(Color.white)
                    .cornerRadius(4)
            }
            Text("to")
                .foregroundColor(.black)
            if growStartDate == 0 || isEditingEnvironmentControls {
                Text(formatTime(end.wrappedValue))
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .frame(width: 100, height: 30)
                    .background(Color.white)
                    .cornerRadius(4)
                    .onTapGesture {
                        selectedTimeBinding = end
                        showingTimePicker = true
                    }
            } else {
                Text(formatTime(end.wrappedValue))
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .frame(width: 100, height: 30)
                    .background(Color.white)
                    .cornerRadius(4)
            }
            Button("24/7") {
                constant.wrappedValue.toggle()
            }
            .foregroundColor(constant.wrappedValue ? .green : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.2))
            )
            .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
        }
    }
    
    @ViewBuilder
    private func functionModeControls(
        title: String,
        functionParams: Binding<(a: Double, b: Double, c: Double, k: Double, n: Int)>
    ) -> some View {
        let a = functionParams.a.wrappedValue
        let b = functionParams.b.wrappedValue
        let c = functionParams.c.wrappedValue
        let k = functionParams.k.wrappedValue
        let n = functionParams.n.wrappedValue
        let difference = a * 100 * (1 - exp(-pow(1 / b, k)))
        let widthPercentage = computeWidth(a: a, b: b, c: c, k: k, n: n)
        let hour = (c + 12) * (23.0 / 24.0) + 1
        let displayHour = Int(hour) % 24
        let hourString = String(format: "%02d", displayHour)
        
        VStack(spacing: 10) {
            VStack {
                Text("Amplitude: \(difference, specifier: "%.2f")%")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: functionParams.a, in: 0...1, step: 0.01)
                    .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
            }
            
            VStack {
                Text("Width: \(widthPercentage, specifier: "%.1f")% ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: functionParams.b, in: 0.1...10.0, step: 0.01)
                    .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
            }
            
            VStack {
                Text("Shift: \(hourString)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: functionParams.c, in: -12...12, step: 0.1)
                    .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
            }
            
            VStack {
                Text("Shape: \(k, specifier: "%.2f")")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: functionParams.k, in: 2.0...4.0, step: 0.1)
                    .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
            }
            
            VStack {
                Text("Frequency: \(n)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(n) },
                    set: { functionParams.n.wrappedValue = Int($0) }
                ), in: 1...12, step: 1)
                    .disabled(growStartDate != 0 && !isEditingEnvironmentControls)
            }
        }
        .padding()
    }
    
    private func computeWidth(a: Double, b: Double, c: Double, k: Double, n: Int) -> Double {
        let f = Double(n) / 48.0
        let threshold = a * 100 * 0.9
        let totalMinutes = 24 * 60
        var activeIntervals: [(start: Int, end: Int)] = []
        var isActive = false
        var startMinute = 0
        
        for t in 0...totalMinutes {
            let x = (Double(t) / Double(totalMinutes)) * 24 - 12
            let theta = 2 * Double.pi * f * (x - c)
            let term = sin(theta) / b
            let y = a * 100 * exp(-pow(abs(term), k))
            
            if y >= threshold && !isActive {
                isActive = true
                startMinute = t
            } else if y < threshold && isActive {
                isActive = false
                activeIntervals.append((start: startMinute, end: t))
            }
        }
        
        if isActive {
            activeIntervals.append((start: startMinute, end: totalMinutes))
        }
        
        let activeMinutes = activeIntervals.reduce(0) { $0 + ($1.end - $1.start) }
        return (Double(activeMinutes) / Double(totalMinutes)) * 100
    }
    
    @ViewBuilder
    private func EnvironmentTabView(selectedTab: Binding<String>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["Environment", "Nutrients"], id: \.self) { tab in
                    Button(action: {
                        withAnimation {
                            selectedTab.wrappedValue = tab
                        }
                    }) {
                        Text(tab)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(selectedTab.wrappedValue == tab ? .black : .gray)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.gray, Color.clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.vertical, 5)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadEnvironmentProfiles() -> [CodableEnvironmentProfile] {
        guard let url = Bundle.main.url(forResource: "environmentProfiles", withExtension: "json") else {
            print("Failed to locate environmentProfiles.json in bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([CodableEnvironmentProfile].self, from: data)
        } catch {
            print("Failed to decode environment profiles: \(error)")
            return []
        }
    }

    private func loadNutrientProfiles() -> [CodableNutrientProfile] {
        guard let url = Bundle.main.url(forResource: "nutrientProfiles", withExtension: "json") else {
            print("Failed to locate nutrientProfiles.json in bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([CodableNutrientProfile].self, from: data)
        } catch {
            print("Failed to decode nutrient profiles: \(error)")
            return []
        }
    }
    
    private func saveEnvironmentProfiles(profiles: [EnvironmentProfile]) {
        // Placeholder for saving environment profiles
    }
    
    private func saveNutrientProfiles(profiles: [NutrientProfile]) {
        // Placeholder for saving nutrient profiles
    }
    
    private func colorFromString(_ colorString: String) -> Color {
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
    
    private func stringFromColor(_ color: Color) -> String {
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
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
