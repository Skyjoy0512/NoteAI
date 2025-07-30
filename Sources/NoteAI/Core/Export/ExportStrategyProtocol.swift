import Foundation

// MARK: - エクスポート戦略パターン

protocol ExportStrategy {
    associatedtype Input
    associatedtype Output
    associatedtype Configuration
    
    var strategyName: String { get }
    var supportedFormats: [ExportFormat] { get }
    var supportedFeatures: [ExportFeature] { get }
    
    func canHandle(_ format: ExportFormat) -> Bool
    func export(input: Input, format: ExportFormat, configuration: Configuration) async throws -> ExportResult
    func estimateSize(input: Input, format: ExportFormat, configuration: Configuration) async throws -> ExportSizeEstimate
    func validate(input: Input, configuration: Configuration) async throws
}

// MARK: - エクスポートコンテキスト

struct ExportContext<T> {
    let data: T
    let format: ExportFormat
    let options: ExportOptions
    let metadata: ExportMetadata
    let progressHandler: ((Double, String?) -> Void)?
    
    init(
        data: T,
        format: ExportFormat,
        options: ExportOptions = ExportOptions(),
        metadata: ExportMetadata? = nil,
        progressHandler: ((Double, String?) -> Void)? = nil
    ) {
        self.data = data
        self.format = format
        self.options = options
        self.metadata = metadata ?? ExportMetadata.default
        self.progressHandler = progressHandler
    }
}

// MARK: - エクスポートパイプライン

protocol ExportPipeline {
    func addProcessor<T: ExportProcessor>(_ processor: T)
    func removeProcessor(named name: String)
    func process<T>(_ context: ExportContext<T>) async throws -> ExportResult
}

protocol ExportProcessor {
    var processorName: String { get }
    var priority: Int { get } // 低い数値ほど高優先度
    
    func canProcess<T>(_ context: ExportContext<T>) -> Bool
    func process<T>(_ context: ExportContext<T>) async throws -> ExportContext<T>
}

// MARK: - エクスポートファクトリ

protocol ExportStrategyFactory {
    func createStrategy(for exportType: ExportType) -> any ExportStrategy
    func createPipeline() -> ExportPipeline
    func registerStrategy<T: ExportStrategy>(_ strategy: T, for type: ExportType)
}

// MARK: - バリデーター

protocol ExportValidator {
    func validate<T>(_ context: ExportContext<T>) async throws -> ExportValidationResult
}

struct ExportValidationResult {
    let isValid: Bool
    let warnings: [ExportWarning]
    let errors: [ExportError]
    let suggestions: [String]
    
    var hasErrors: Bool {
        return !errors.isEmpty
    }
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
}

// MARK: - メタデータ拡張

extension ExportMetadata {
    static var `default`: ExportMetadata {
        return ExportMetadata(
            originalDataSize: 0,
            compressionRatio: 1.0,
            exportDuration: 0.0,
            itemCount: 0,
            includedDataTypes: [],
            qualityMetrics: ExportQualityMetrics(
                dataCompleteness: 1.0,
                formatConsistency: 1.0,
                validationScore: 1.0,
                errorCount: 0
            ),
            warnings: []
        )
    }
}

// MARK: - エラー拡張

enum ExportError: Error, LocalizedError {
    case strategyNotFound(ExportType)
    case unsupportedFormat(ExportFormat, String)
    case validationFailed([ExportValidationError])
    case processingFailed(String, Error?)
    case configurationError(String)
    case resourceNotAvailable(String)
    case sizeLimitExceeded(Int64, Int64) // current, limit
    
    var errorDescription: String? {
        switch self {
        case .strategyNotFound(let type):
            return "Export strategy not found for type: \(type.rawValue)"
        case .unsupportedFormat(let format, let context):
            return "Unsupported format \(format.rawValue) for \(context)"
        case .validationFailed(let errors):
            return "Validation failed with \(errors.count) errors"
        case .processingFailed(let stage, let error):
            return "Processing failed at stage '\(stage)': \(error?.localizedDescription ?? "Unknown error")"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .resourceNotAvailable(let resource):
            return "Resource not available: \(resource)"
        case .sizeLimitExceeded(let current, let limit):
            return "Size limit exceeded: \(current) bytes > \(limit) bytes"
        }
    }
}

struct ExportValidationError: Error, LocalizedError {
    let field: String
    let message: String
    let severity: ValidationSeverity
    
    var errorDescription: String? {
        return "\(field): \(message)"
    }
}

enum ValidationSeverity {
    case warning
    case error
    case critical
}