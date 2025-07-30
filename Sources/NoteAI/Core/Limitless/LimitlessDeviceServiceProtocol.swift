import Foundation

// MARK: - Limitlessデバイスサービスプロトコル

@MainActor
protocol LimitlessDeviceServiceProtocol: ObservableObject {
    var isConnected: Bool { get }
    var currentDevice: LimitlessDevice? { get }
    var connectedDevice: LimitlessDevice? { get }
    var connectionStatus: DeviceConnectionStatus { get }
    
    func connectToDevice() async throws
    func disconnectFromDevice() async throws
    func sendCommand(_ command: DeviceCommand) async throws -> DeviceResponse
    func getDeviceStatus() async throws -> DeviceStatus
    func startContinuousRecording() async throws
    func stopContinuousRecording() async throws
    func syncAudioFiles() async throws -> [AudioFileInfo]
}

// MARK: - サポート型

enum DeviceConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

struct DeviceCommand {
    let type: CommandType
    let parameters: [String: Any]
    
    enum CommandType: String {
        case startRecording = "start_recording"
        case stopRecording = "stop_recording"
        case setRecordingQuality = "set_recording_quality"
        case setBatteryOptimization = "set_battery_optimization"
        case getStatus = "get_status"
        case syncData = "sync_data"
        case heartbeat = "heartbeat"
    }
}

struct DeviceStatus {
    let batteryLevel: Int
    let signalStrength: Int
    let isRecording: Bool
    let storageAvailable: Int64
}

struct LimitlessDevice {
    let id: UUID
    let name: String
    let deviceType: DeviceType
    let firmwareVersion: String
    var batteryLevel: Int
    var signalStrength: Int
    
    enum DeviceType: String {
        case pendant = "pendant"
        case clip = "clip"
        case watch = "watch"
        case pin = "pin"
        case bluetooth = "bluetooth"
        case wifi = "wifi"
    }
}

struct DeviceResponse {
    let success: Bool
    let data: [String: Any]
    let error: String?
}

// Alias for backward compatibility
typealias ConnectionStatus = DeviceConnectionStatus