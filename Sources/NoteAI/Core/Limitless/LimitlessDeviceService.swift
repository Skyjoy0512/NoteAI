import Foundation
import Combine
import Network

// MARK: - Limitlessデバイス接続サービス

@MainActor
class LimitlessDeviceService: LimitlessDeviceServiceProtocol {
    
    // MARK: - Protocol Required Properties
    var isConnected: Bool {
        return connectionStatus == .connected
    }
    
    var currentDevice: LimitlessDevice? {
        return connectedDevice
    }
    
    // MARK: - Published Properties
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var connectedDevice: LimitlessDevice?
    @Published var discoveredDevices: [LimitlessDevice] = []
    @Published var isScanning: Bool = false
    @Published var lastError: LimitlessError?
    
    // MARK: - Private Properties
    private let logger = RAGLogger.shared
    private let performanceMonitor = RAGPerformanceMonitor.shared
    private let settings = LimitlessSettings.shared
    private let networkManager = NetworkManager()
    private let deviceDiscovery = DeviceDiscoveryManager()
    private let connectionManager = DeviceConnectionManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var heartbeatTimer: Timer?
    
    // MARK: - Configuration
    private struct Config {
        static let scanTimeout: TimeInterval = 30.0
        static let connectionTimeout: TimeInterval = 10.0
        static let heartbeatInterval: TimeInterval = 5.0
        static let maxRetryAttempts = 3
        static let commandTimeout: TimeInterval = 15.0
        static let maxDeviceDistance: Double = 50.0
    }
    
    init() {
        setupObservers()
        setupHeartbeat()
    }
    
    deinit {
        Task { [weak self] in
            await self?.cleanup()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupObservers() {
        // Device discovery updates
        deviceDiscovery.discoveredDevicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.discoveredDevices = devices
            }
            .store(in: &cancellables)
        
        // Connection status updates
        connectionManager.connectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
            }
            .store(in: &cancellables)
        
        // Connected device updates
        connectionManager.connectedDevicePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device in
                self?.connectedDevice = device
            }
            .store(in: &cancellables)
        
        // Error handling
        Publishers.Merge3(
            deviceDiscovery.errorPublisher,
            connectionManager.errorPublisher,
            networkManager.errorPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] error in
            self?.handleError(error)
        }
        .store(in: &cancellables)
    }
    
    private func setupHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Config.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { await self?.performHeartbeat() }
        }
    }
    
    private func cleanup() async {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        stopScanning()
        await disconnect()
    }
    
    // MARK: - Public Methods
    
    func startScanning() async {
        guard !isScanning else { return }
        
        let measurement = performanceMonitor.startMeasurement()
        defer {
            performanceMonitor.recordMetric(
                operation: "Device Scanning",
                measurement: measurement,
                success: !isScanning
            )
        }
        
        logger.log(level: .info, message: "Starting device scanning")
        isScanning = true
        
        do {
            try await deviceDiscovery.startScanning(timeout: Config.scanTimeout)
        } catch {
            handleError(.deviceError(.scanningFailed(error.localizedDescription)))
            isScanning = false
        }
    }
    
    func stopScanning() {
        guard isScanning else { return }
        
        logger.log(level: .info, message: "Stopping device scanning")
        isScanning = false
        deviceDiscovery.stopScanning()
    }
    
    func connectToDevice() async throws {
        // Default implementation - connect to first available device
        if let device = discoveredDevices.first {
            try await connect(to: device)
        } else {
            throw LimitlessError.deviceError(.deviceNotFound)
        }
    }
    
    func disconnectFromDevice() async throws {
        await disconnect()
    }
    
    func getDeviceStatus() async throws -> DeviceStatus {
        guard let device = connectedDevice else {
            throw LimitlessError.deviceError(.notConnected)
        }
        
        return DeviceStatus(
            batteryLevel: device.batteryLevel,
            signalStrength: device.signalStrength,
            isRecording: false, // TODO: Track actual recording state
            storageAvailable: 1024 * 1024 * 1024 // 1GB placeholder
        )
    }
    
    func connect(to device: LimitlessDevice) async throws {
        guard connectionStatus != .connected else {
            throw LimitlessError.deviceError(.alreadyConnected)
        }
        
        let measurement = performanceMonitor.startMeasurement()
        defer {
            performanceMonitor.recordMetric(
                operation: "Device Connection",
                measurement: measurement,
                success: connectionStatus == .connected
            )
        }
        
        logger.log(level: .info, message: "Connecting to device", context: [
            "deviceId": device.id,
            "deviceName": device.name
        ])
        
        do {
            try await connectionManager.connect(to: device, timeout: Config.connectionTimeout)
            await startDataSync()
        } catch {
            handleError(.deviceError(.connectionFailed(error.localizedDescription)))
            throw error
        }
    }
    
    func disconnect() async {
        guard connectionStatus == .connected else { return }
        
        logger.log(level: .info, message: "Disconnecting from device")
        
        await stopDataSync()
        await connectionManager.disconnect()
    }
    
    func sendCommand(_ command: DeviceCommand) async throws -> DeviceResponse {
        guard connectionStatus == .connected else {
            throw LimitlessError.deviceError(.notConnected)
        }
        
        let measurement = performanceMonitor.startMeasurement()
        defer {
            performanceMonitor.recordMetric(
                operation: "Command: \(command.type.rawValue)",
                measurement: measurement,
                success: true
            )
        }
        
        do {
            return try await connectionManager.sendCommand(command, timeout: Config.commandTimeout)
        } catch {
            handleError(.deviceError(.commandFailed(error.localizedDescription)))
            throw error
        }
    }
    
    func startContinuousRecording() async throws {
        let command = DeviceCommand(
            type: .startRecording,
            parameters: [
                "quality": settings.recordingQuality.rawValue,
                "batteryOptimization": settings.batteryOptimizationEnabled
            ]
        )
        
        let _ = try await sendCommand(command)
    }
    
    func stopContinuousRecording() async throws {
        let command = DeviceCommand(type: .stopRecording, parameters: [:])
        let _ = try await sendCommand(command)
    }
    
    func syncAudioFiles() async throws -> [AudioFileInfo] {
        let command = DeviceCommand(type: .syncData, parameters: [:])
        let response = try await sendCommand(command)
        
        // Parse audio files from response
        return parseAudioFilesFromResponse(response)
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: LimitlessError) {
        lastError = error
        logger.log(level: .error, message: "Limitless error", context: [
            "error": error.localizedDescription
        ])
    }
    
    private func performHeartbeat() async {
        guard connectionStatus == .connected else { return }
        
        do {
            let command = DeviceCommand(type: .heartbeat, parameters: [:])
            let response = try await sendCommand(command)
            
            // Update device status from heartbeat response
            await updateDeviceStatus(from: response)
            
        } catch {
            logger.log(level: .warning, message: "Heartbeat failed", context: [
                "error": error.localizedDescription
            ])
            
            // Handle connection loss
            if case .deviceError(.commandFailed) = error as? LimitlessError {
                await disconnect()
            }
        }
    }
    
    private func startDataSync() async {
        // Start periodic data synchronization
        logger.log(level: .info, message: "Starting data sync")
    }
    
    private func stopDataSync() async {
        // Stop data synchronization
        logger.log(level: .info, message: "Stopping data sync")
    }
    
    private func updateDeviceStatus(from response: DeviceResponse) async {
        guard let device = connectedDevice else { return }
        
        // Update device properties from response data
        var updatedDevice = device
        
        if let batteryLevel = response.data["batteryLevel"] as? Int {
            updatedDevice.batteryLevel = batteryLevel
        }
        
        if let signalStrength = response.data["signalStrength"] as? Int {
            updatedDevice.signalStrength = signalStrength
        }
        
        connectedDevice = updatedDevice
    }
    
    private func parseAudioFilesFromResponse(_ response: DeviceResponse) -> [AudioFileInfo] {
        // Mock implementation
        return []
    }
}

// MARK: - Supporting Classes

/// ネットワーク管理
private class NetworkManager {
    let errorPublisher = PassthroughSubject<LimitlessError, Never>()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "network.monitor")
    
    init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status != .satisfied {
                self?.errorPublisher.send(.networkError("ネットワーク接続が失われました"))
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
}

/// デバイス発見管理
private class DeviceDiscoveryManager {
    let discoveredDevicesPublisher = CurrentValueSubject<[LimitlessDevice], Never>([])
    let errorPublisher = PassthroughSubject<LimitlessError, Never>()
    
    private var isScanning = false
    private var scanningTask: Task<Void, Never>?
    
    func startScanning(timeout: TimeInterval) async throws {
        guard !isScanning else { return }
        
        isScanning = true
        
        scanningTask = Task {
            await performScanning()
            
            // Timeout handling
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if !Task.isCancelled {
                stopScanning()
            }
        }
    }
    
    func stopScanning() {
        isScanning = false
        scanningTask?.cancel()
        scanningTask = nil
    }
    
    private func performScanning() async {
        // Mock device discovery
        let mockDevices = [
            LimitlessDevice(
                id: UUID(),
                name: "Limitless Pendant",
                deviceType: .pendant,
                firmwareVersion: "2.1.0",
                batteryLevel: 85,
                signalStrength: 4
            ),
            LimitlessDevice(
                id: UUID(), 
                name: "Limitless Pin",
                deviceType: .pin,
                firmwareVersion: "2.0.8",
                batteryLevel: 92,
                signalStrength: 5
            )
        ]
        
        discoveredDevicesPublisher.send(mockDevices)
    }
}

/// デバイス接続管理
private class DeviceConnectionManager {
    let connectionStatusPublisher = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    let connectedDevicePublisher = CurrentValueSubject<LimitlessDevice?, Never>(nil)
    let errorPublisher = PassthroughSubject<LimitlessError, Never>()
    
    private var connectionTask: Task<Void, Never>?
    
    func connect(to device: LimitlessDevice, timeout: TimeInterval) async throws {
        connectionStatusPublisher.send(.connecting)
        
        connectionTask = Task {
            do {
                // Simulate connection process
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                if !Task.isCancelled {
                    connectionStatusPublisher.send(.connected)
                    connectedDevicePublisher.send(device)
                }
            } catch {
                if !Task.isCancelled {
                    connectionStatusPublisher.send(.error("Connection failed"))
                    errorPublisher.send(.deviceError(.connectionFailed(error.localizedDescription)))
                }
            }
        }
        
        // Timeout handling
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw DeviceError.connectionTimeout
            }
            
            group.addTask {
                await self.connectionTask?.value
            }
            
            try await group.next()
            group.cancelAll()
        }
    }
    
    func disconnect() async {
        connectionTask?.cancel()
        connectionStatusPublisher.send(.disconnected)
        connectedDevicePublisher.send(nil)
    }
    
    func sendCommand(_ command: DeviceCommand, timeout: TimeInterval) async throws -> DeviceResponse {
        // Mock command execution
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return DeviceResponse(
            success: true,
            data: [:],
            error: nil
        )
    }
}

