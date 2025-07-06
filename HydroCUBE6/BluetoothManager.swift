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
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectionState: ConnectionState = .idle
    
    var centralManager: CBCentralManager!
    private var targetCharacteristic: CBCharacteristic? // Store the writable characteristic
    
    private var messageQueue: [String] = []
    private let maxPacketSize = 20
    
    // UUIDs for the service and characteristics
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let writeCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Adjust if needed
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        connectionState = .connecting
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // Function to send a message to the connected device
    func sendMessage(_ message: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = targetCharacteristic else {
            print("Cannot send message: Peripheral or characteristic not ready")
            return
        }
        
        let chunks = chunkMessage(message)
        messageQueue.append(contentsOf: chunks)
        sendNextFromQueue(to: peripheral, characteristic: characteristic)
    }
    
    // Break message into chunks with delimiters
    private func chunkMessage(_ message: String) -> [String] {
        var chunks: [String] = []
        var remaining = message
        
        while !remaining.isEmpty {
            let chunk = String(remaining.prefix(maxPacketSize))
            chunks.append(chunk)
            remaining = String(remaining.dropFirst(maxPacketSize))
        }
        chunks.append("\n")
        
        return chunks
    }
    
    // Send a single chunk
    private func sendChunk(_ chunk: String, to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard let data = chunk.data(using: .utf8) else { return }
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)
        print("Sent chunk: \(chunk)")
    }
    
    // Send next message from queue
    private func sendNextFromQueue(to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard !messageQueue.isEmpty else { return }
        
        let chunk = messageQueue.removeFirst()
        sendChunk(chunk, to: peripheral, characteristic: characteristic)
        
        // Send next chunk immediately (no waiting for response)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.sendNextFromQueue(to: peripheral, characteristic: characteristic)
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Bluetooth is ready
        } else {
            // Handle Bluetooth off, unauthorized, etc.
            print("Bluetooth state: \(central.state)")
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
        
        // Set the peripheral's delegate and start discovering services
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .failed
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral == peripheral {
            connectedPeripheral = nil
            targetCharacteristic = nil // Clear the characteristic
            connectionState = .idle
        }
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                // Discover characteristics for the target service
                peripheral.discoverCharacteristics([writeCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == writeCharacteristicUUID {
                targetCharacteristic = characteristic
                print("Found writable characteristic: \(characteristic.uuid)")
                
                // Optionally, enable notifications if the characteristic supports it
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    // Optional: Handle incoming data if the characteristic supports notifications
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error receiving data: \(error.localizedDescription)")
            return
        }
        
        if let value = characteristic.value, let message = String(data: value, encoding: .utf8) {
            print("Received message: \(message)")
        }
    }
}
