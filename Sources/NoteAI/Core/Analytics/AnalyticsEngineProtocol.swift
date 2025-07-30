import Foundation

// MARK: - 分析エンジンの統一インターフェース

@MainActor
protocol AnalyticsEngineProtocol {
    associatedtype Input
    associatedtype Output: Codable
    associatedtype Configuration
    
    var engineName: String { get }
    var supportedOperations: [String] { get }
    var defaultConfiguration: Configuration { get }
    
    func execute(input: Input, configuration: Configuration?) async throws -> AnalyticsResult<Output>
    func validateInput(_ input: Input) async throws
    func estimateExecutionTime(for input: Input) -> TimeInterval
}

// MARK: - 分析結果の統一型

struct AnalyticsResult<T: Codable>: Codable {
    let data: T
    let confidence: Double
    let processingTime: TimeInterval
    let qualityMetrics: QualityMetrics
    let metadata: AnalyticsResultMetadata
    let cacheKey: String?
    
    init(
        data: T,
        confidence: Double,
        processingTime: TimeInterval,
        qualityMetrics: QualityMetrics,
        metadata: AnalyticsResultMetadata,
        cacheKey: String? = nil
    ) {
        self.data = data
        self.confidence = confidence
        self.processingTime = processingTime
        self.qualityMetrics = qualityMetrics
        self.metadata = metadata
        self.cacheKey = cacheKey
    }
}

struct QualityMetrics: Codable {
    let dataCompleteness: Double    // 0.0 - 1.0
    let dataAccuracy: Double        // 0.0 - 1.0
    let resultReliability: Double   // 0.0 - 1.0
    let statisticalSignificance: Double? // p-value if applicable
    
    var overallQuality: Double {
        let weights = [0.3, 0.3, 0.4] // completeness, accuracy, reliability
        let values = [dataCompleteness, dataAccuracy, resultReliability]
        return zip(weights, values).map(*).reduce(0, +)
    }
}

struct AnalyticsResultMetadata: Codable {
    let engineName: String
    let modelVersion: String
    let parameterHash: String
    let executionEnvironment: ExecutionEnvironment
    let timestamp: Date
    let warnings: [AnalyticsWarning]
    let debugInfo: [String: String]?
}

struct ExecutionEnvironment: Codable {
    let systemInfo: String
    let memoryUsage: UInt64
    let cpuUsage: Double
    let networkLatency: TimeInterval?
}

struct AnalyticsWarning: Codable {
    let level: WarningLevel
    let message: String
    let recommendation: String?
    let affectedMetrics: [String]
}

enum WarningLevel: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

// MARK: - 分析エンジンの基底クラス

@MainActor
class BaseAnalyticsEngine<Input, Output: Codable, Config>: AnalyticsEngineProtocol {
    
    // MARK: - 共通依存関係
    internal let cache = RAGCache.shared
    internal let logger = RAGLogger.shared
    internal let performanceMonitor = RAGPerformanceMonitor.shared
    
    // MARK: - エンジン設定
    internal let engineName: String
    internal let supportedOperations: [String]
    internal let defaultConfiguration: Config
    
    // MARK: - パフォーマンス設定
    private let maxCacheAge: TimeInterval = 3600 // 1時間
    private let maxConcurrentOperations: Int = 3
    private var activeOperations = 0
    
    init(
        engineName: String,
        supportedOperations: [String],
        defaultConfiguration: Config
    ) {
        self.engineName = engineName
        self.supportedOperations = supportedOperations
        self.defaultConfiguration = defaultConfiguration
    }
    
    // MARK: - 実行フレームワーク
    
    func executeWithFramework(
        input: Input,
        configuration: Config?,
        operation: String
    ) async throws -> AnalyticsResult<Output> {
        
        // 同時実行制限チェック
        try await checkConcurrencyLimit()
        
        let measurement = performanceMonitor.startMeasurement()
        let config = configuration ?? defaultConfiguration
        let cacheKey = generateCacheKey(input: input, config: config, operation: operation)
        
        activeOperations += 1
        defer { activeOperations -= 1 }
        
        do {
            // キャッシュチェック
            if let cachedResult: AnalyticsResult<Output> = await cache.get(key: cacheKey, type: AnalyticsResult<Output>.self) {
                logger.log(level: .debug, message: "Cache hit for analytics operation", context: [
                    "engine": engineName,
                    "operation": operation,
                    "cacheKey": cacheKey
                ])
                
                performanceMonitor.recordMetric(
                    operation: "\(engineName)_\(operation)",
                    measurement: measurement,
                    success: true,
                    metadata: ["cached": true]
                )
                
                return cachedResult
            }
            
            // 入力検証
            try await validateInput(input)
            
            logger.log(level: .info, message: "Starting analytics operation", context: [
                "engine": engineName,
                "operation": operation
            ])
            
            // 実際の分析実行
            let result = try await performAnalysis(input: input, configuration: config)
            
            // 品質メトリクス計算
            let qualityMetrics = try await calculateQualityMetrics(
                input: input,
                output: result,
                configuration: config
            )
            
            // メタデータ構築
            let metadata = buildMetadata(
                operation: operation,
                measurement: measurement,
                warnings: try await identifyWarnings(input: input, output: result)
            )
            
            let analyticsResult = AnalyticsResult(
                data: result,
                confidence: qualityMetrics.overallQuality,
                processingTime: measurement.duration,
                qualityMetrics: qualityMetrics,
                metadata: metadata,
                cacheKey: cacheKey
            )
            
            // 結果キャッシュ
            await cache.set(
                key: cacheKey,
                value: analyticsResult,
                expiration: maxCacheAge
            )
            
            performanceMonitor.recordMetric(
                operation: "\(engineName)_\(operation)",
                measurement: measurement,
                success: true,
                metadata: [
                    "confidence": analyticsResult.confidence,
                    "qualityScore": qualityMetrics.overallQuality
                ]
            )
            
            logger.log(level: .info, message: "Analytics operation completed", context: [
                "engine": engineName,
                "operation": operation,
                "confidence": analyticsResult.confidence,
                "duration": measurement.duration
            ])
            
            return analyticsResult
            
        } catch {
            performanceMonitor.recordMetric(
                operation: "\(engineName)_\(operation)",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Analytics operation failed", context: [
                "engine": engineName,
                "operation": operation,
                "error": error.localizedDescription
            ])
            
            throw AnalyticsEngineError.executionFailed(engineName, operation, error.localizedDescription)
        }
    }
    
    // MARK: - 抽象メソッド（サブクラスで実装）
    
    func performAnalysis(input: Input, configuration: Config) async throws -> Output {
        fatalError("performAnalysis must be implemented by subclass")
    }
    
    func validateInput(_ input: Input) async throws {
        // デフォルト実装（サブクラスでオーバーライド可能）
    }
    
    func calculateQualityMetrics(input: Input, output: Output, configuration: Config) async throws -> QualityMetrics {
        // デフォルト実装
        return QualityMetrics(
            dataCompleteness: 0.8,
            dataAccuracy: 0.8,
            resultReliability: 0.8,
            statisticalSignificance: nil
        )
    }
    
    func identifyWarnings(input: Input, output: Output) async throws -> [AnalyticsWarning] {
        // デフォルト実装
        return []
    }
    
    // MARK: - AnalyticsEngineProtocol実装
    
    func execute(input: Input, configuration: Config?) async throws -> AnalyticsResult<Output> {
        return try await executeWithFramework(
            input: input, 
            configuration: configuration ?? defaultConfiguration,
            operation: "execute"
        )
    }
    
    func estimateExecutionTime(for input: Input) -> TimeInterval {
        // デフォルト実装（サブクラスでオーバーライド）
        return 5.0
    }
    
    // MARK: - 内部ヘルパーメソッド
    
    private func checkConcurrencyLimit() async throws {
        guard activeOperations < maxConcurrentOperations else {
            throw AnalyticsEngineError.concurrencyLimitExceeded(maxConcurrentOperations)
        }
    }
    
    private func generateCacheKey(input: Input, config: Config, operation: String) -> String {
        // 入力とコンフィグのハッシュを生成
        let inputHash = String(describing: input).hash
        let configHash = String(describing: config).hash
        
        return "\(engineName)_\(operation)_\(inputHash)_\(configHash)_1.0.0"
    }
    
    private func buildMetadata(
        operation: String,
        measurement: PerformanceMeasurement,
        warnings: [AnalyticsWarning]
    ) -> AnalyticsResultMetadata {
        
        return AnalyticsResultMetadata(
            engineName: engineName,
            modelVersion: "1.0.0", // TODO: バージョン管理システムから取得
            parameterHash: "hash", // TODO: 実際のパラメータハッシュ
            executionEnvironment: ExecutionEnvironment(
                systemInfo: getSystemInfo(),
                memoryUsage: getMemoryUsage(),
                cpuUsage: getCPUUsage(),
                networkLatency: nil
            ),
            timestamp: measurement.startTime,
            warnings: warnings,
            debugInfo: nil // TODO: デバッグ情報を追加
        )
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.virtual_size) / (1024 * 1024 * 1024) // GB
        } else {
            return 0.0
        }
    }
}

// MARK: - 分析エンジン専用エラー

enum AnalyticsEngineError: Error, LocalizedError {
    case executionFailed(String, String, String) // engine, operation, reason
    case invalidInput(String, String) // engine, reason
    case concurrencyLimitExceeded(Int) // maxLimit
    case configurationError(String, String) // engine, reason
    case insufficientData(String, Int, Int) // engine, required, available
    
    var errorDescription: String? {
        switch self {
        case .executionFailed(let engine, let operation, let reason):
            return "Analytics engine '\(engine)' failed to execute '\(operation)': \(reason)"
        case .invalidInput(let engine, let reason):
            return "Invalid input for engine '\(engine)': \(reason)"
        case .concurrencyLimitExceeded(let maxLimit):
            return "Concurrency limit exceeded. Maximum \(maxLimit) operations allowed."
        case .configurationError(let engine, let reason):
            return "Configuration error for engine '\(engine)': \(reason)"
        case .insufficientData(let engine, let required, let available):
            return "Insufficient data for engine '\(engine)': required \(required), available \(available)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .executionFailed:
            return "エンジンの設定を確認し、再試行してください"
        case .invalidInput:
            return "入力パラメータを確認してください"
        case .concurrencyLimitExceeded:
            return "しばらく待ってから再試行してください"
        case .configurationError:
            return "エンジンの設定を見直してください"
        case .insufficientData:
            return "より多くのデータを収集してください"
        }
    }
}

// MARK: - システム情報取得

#if canImport(UIKit)
import UIKit
#endif
import Darwin

// MARK: - システム情報関数

private func getSystemInfo() -> String {
    #if canImport(UIKit)
    return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    #else
    // macOSやその他のプラットフォーム用
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    #endif
}

private func getMemoryUsage() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        return Double(info.resident_size) / (1024 * 1024) // MB
    }
    return 0.0
}

private func getCPUUsage() -> Double {
    // 簡易的なCPU使用率取得
    // 実際のアプリではより詳細な実装が必要
    return 0.0
}