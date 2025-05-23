import CoreBluetooth
import SwiftUI

// Enum to represent connection states
enum ConnectionState {
    case idle
    case connecting
    case connected
    case failed
}

class BluetoothManager: NSObject, ObservableObject {
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral? // Tracks the connected peripheral
    @Published var connectionState: ConnectionState = .idle // Tracks connection status
    
    var centralManager: CBCentralManager!
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")], options: nil)
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        connectionState = .connecting // Set state to connecting
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Bluetooth is ready
        } else {
            // Handle Bluetooth off, unauthorized, etc.
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectionState = .connected
        print("Connected to \(peripheral.name ?? "Unknown Device")")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .failed
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral == peripheral {
            connectedPeripheral = nil
            connectionState = .idle
        }
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
    }
}
