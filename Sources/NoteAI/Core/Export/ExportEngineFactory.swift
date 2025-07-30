import Foundation

// MARK: - エクスポートエンジンプロトコル

protocol ExportEngine {
    var engineName: String { get }
    var supportedFeatures: [ExportFeature] { get }
    var outputMimeType: String { get }
    
    func export(content: Any, options: Any) async throws -> ExportContent
    func validateContent(_ content: Any) -> Bool
}

// MARK: - エクスポートエンジンファクトリ

protocol ExportEngineFactory {
    func createEngine(for format: ExportFormat) throws -> any ExportEngine
    func registerEngine<T: ExportEngine>(_ engine: T, for format: ExportFormat)
    func supportedFormats() -> [ExportFormat]
}

class DefaultExportEngineFactory: ExportEngineFactory {
    
    private var engines: [ExportFormat: any ExportEngine] = [:]
    
    init() {
        registerDefaultEngines()
    }
    
    func createEngine(for format: ExportFormat) throws -> any ExportEngine {
        guard let engine = engines[format] else {
            throw ExportError.unsupportedFormat(format, "No engine registered for format")
        }
        return engine
    }
    
    func registerEngine<T: ExportEngine>(_ engine: T, for format: ExportFormat) {
        engines[format] = engine
    }
    
    func supportedFormats() -> [ExportFormat] {
        return Array(engines.keys)
    }
    
    private func registerDefaultEngines() {
        registerEngine(RefactoredPDFExportEngine(), for: .pdf)
        registerEngine(RefactoredWordExportEngine(), for: .docx)
        registerEngine(RefactoredHTMLExportEngine(), for: .html)
        registerEngine(RefactoredMarkdownExportEngine(), for: .markdown)
        registerEngine(RefactoredDataExportEngine(), for: .json)
        registerEngine(RefactoredDataExportEngine(), for: .csv)
        registerEngine(ZipExportEngine(), for: .zip)
    }
}

// MARK: - リファクタリングされたエンジン群

// MARK: - ベースエンジン

class BaseExportEngine: ExportEngine {
    
    let engineName: String
    let supportedFeatures: [ExportFeature]
    let outputMimeType: String
    
    // 共通ユーティリティ
    let logger = RAGLogger.shared
    let performanceMonitor = RAGPerformanceMonitor.shared
    
    init(
        engineName: String,
        supportedFeatures: [ExportFeature],
        outputMimeType: String
    ) {
        self.engineName = engineName
        self.supportedFeatures = supportedFeatures
        self.outputMimeType = outputMimeType
    }
    
    func export(content: Any, options: Any) async throws -> ExportContent {
        let measurement = performanceMonitor.startMeasurement()
        
        do {
            logger.log(level: .info, message: "Starting export with \(engineName)", context: [:])
            
            // 入力検証
            guard validateContent(content) else {
                throw ExportError.validationFailed([
                    ExportValidationError(
                        field: "content",
                        message: "Invalid content for \(engineName)",
                        severity: .error
                    )
                ])
            }
            
            // 実際のエクスポート処理
            let result = try await performExport(content: content, options: options)
            
            performanceMonitor.recordMetric(
                operation: "export_\(engineName)",
                measurement: measurement,
                success: true,
                metadata: [
                    "outputSize": result.data.count,
                    "mimeType": result.mimeType
                ]
            )
            
            logger.log(level: .info, message: "Export completed with \(engineName)", context: [
                "outputSize": result.data.count,
                "duration": measurement.duration
            ])
            
            return result
            
        } catch {
            performanceMonitor.recordMetric(
                operation: "export_\(engineName)",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Export failed with \(engineName)", context: [
                "error": error.localizedDescription
            ])
            
            throw error
        }
    }
    
    func validateContent(_ content: Any) -> Bool {
        // デフォルト実装（サブクラスでオーバーライド可能）
        return true
    }
    
    // サブクラスで実装が必要
    func performExport(content: Any, options: Any) async throws -> ExportContent {
        fatalError("performExport must be overridden by subclass")
    }
}

// MARK: - PDFエンジン

class RefactoredPDFExportEngine: BaseExportEngine {
    
    init() {
        super.init(
            engineName: "RefactoredPDFEngine",
            supportedFeatures: [.richText, .images, .charts, .tables, .metadata],
            outputMimeType: "application/pdf"
        )
    }
    
    override func performExport(content: Any, options: Any) async throws -> ExportContent {
        // TODO: 実際のPDF生成ロジック
        // Core Graphicsやサードパーティライブラリを使用
        
        let pdfData = try await generatePDFData(content: content, options: options)
        
        return ExportContent(
            data: pdfData,
            mimeType: outputMimeType
        )
    }
    
    override func validateContent(_ content: Any) -> Bool {
        return content is ProjectDocumentContent
    }
    
    private func generatePDFData(content: Any, options: Any) async throws -> Data {
        // TODO: PDF生成の実装
        // 1. ドキュメント構造を解析
        // 2. レイアウトエンジンでページを構成
        // 3. コンテンツをレンダリング
        // 4. PDFバイナリを生成
        
        return Data("Mock PDF Content".utf8)
    }
}

// MARK: - Wordエンジン

class RefactoredWordExportEngine: BaseExportEngine {
    
    init() {
        super.init(
            engineName: "RefactoredWordEngine",
            supportedFeatures: [.richText, .images, .charts, .tables, .hyperlinks, .metadata],
            outputMimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
    }
    
    override func performExport(content: Any, options: Any) async throws -> ExportContent {
        let wordData = try await generateWordDocument(content: content, options: options)
        
        return ExportContent(
            data: wordData,
            mimeType: outputMimeType
        )
    }
    
    private func generateWordDocument(content: Any, options: Any) async throws -> Data {
        // TODO: Open XML形式でWord文書を生成
        return Data("Mock Word Document".utf8)
    }
}

// MARK: - HTMLエンジン

class RefactoredHTMLExportEngine: BaseExportEngine {
    
    init() {
        super.init(
            engineName: "RefactoredHTMLEngine",
            supportedFeatures: [.richText, .images, .charts, .tables, .hyperlinks, .interactivity],
            outputMimeType: "text/html"
        )
    }
    
    override func performExport(content: Any, options: Any) async throws -> ExportContent {
        let htmlContent = try await generateHTML(content: content, options: options)
        
        return ExportContent(
            data: Data(htmlContent.utf8),
            mimeType: outputMimeType
        )
    }
    
    private func generateHTML(content: Any, options: Any) async throws -> String {
        guard let documentContent = content as? ProjectDocumentContent else {
            throw ExportError.validationFailed([
                ExportValidationError(
                    field: "content",
                    message: "Expected ProjectDocumentContent",
                    severity: .error
                )
            ])
        }
        
        var html = """
        <!DOCTYPE html>
        <html lang="ja">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(documentContent.title)</title>
            <style>
                \(getDefaultCSS())
            </style>
        </head>
        <body>
            <header>
                <h1>\(documentContent.title)</h1>
        """
        
        if let subtitle = documentContent.subtitle {
            html += "<p class=\"subtitle\">\(subtitle)</p>"
        }
        
        html += "</header><main>"
        
        // セクションをHTMLに変換
        for section in documentContent.sections {
            html += try await convertSectionToHTML(section)
        }
        
        html += "</main></body></html>"
        
        return html
    }
    
    private func convertSectionToHTML(_ section: DocumentSection) async throws -> String {
        var html = "<section>"
        html += "<h2>\(section.title)</h2>"
        
        switch section.content {
        case .richText(let elements):
            for element in elements {
                html += convertElementToHTML(element)
            }
        case .plainText(let text):
            html += "<p>\(text)</p>"
        case .html(let htmlContent):
            html += htmlContent
        case .markdown(let markdown):
            // TODO: MarkdownをHTMLに変換
            html += "<p>\(markdown)</p>"
        }
        
        html += "</section>"
        return html
    }
    
    private func convertElementToHTML(_ element: DocumentElement) -> String {
        switch element {
        case .heading(let text, let level):
            return "<h\(level + 1)>\(text)</h\(level + 1)>"
        case .paragraph(let text):
            return "<p>\(text)</p>"
        case .list(let items, let ordered):
            let tag = ordered ? "ol" : "ul"
            let listItems = items.map { "<li>\($0)</li>" }.joined()
            return "<\(tag)>\(listItems)</\(tag)>"
        case .table(let headers, let rows):
            return generateHTMLTable(headers: headers, rows: rows)
        case .image(let url, let caption):
            var img = "<img src=\"\(url.absoluteString)\" alt=\"\(caption ?? "")\">"
            if let caption = caption {
                img = "<figure>\(img)<figcaption>\(caption)</figcaption></figure>"
            }
            return img
        case .separator:
            return "<hr>"
        case .metadata(let data):
            return generateMetadataHTML(data)
        default:
            return ""
        }
    }
    
    private func generateHTMLTable(headers: [String], rows: [[String]]) -> String {
        var table = "<table><thead><tr>"
        for header in headers {
            table += "<th>\(header)</th>"
        }
        table += "</tr></thead><tbody>"
        
        for row in rows {
            table += "<tr>"
            for cell in row {
                table += "<td>\(cell)</td>"
            }
            table += "</tr>"
        }
        
        table += "</tbody></table>"
        return table
    }
    
    private func generateMetadataHTML(_ metadata: [String: Any]) -> String {
        var html = "<dl class=\"metadata\">"
        for (key, value) in metadata {
            html += "<dt>\(key)</dt><dd>\(value)</dd>"
        }
        html += "</dl>"
        return html
    }
    
    private func getDefaultCSS() -> String {
        return """
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; margin: 2rem; }
        h1, h2, h3, h4, h5, h6 { color: #333; }
        .subtitle { color: #666; font-size: 1.2rem; }
        table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
        th, td { border: 1px solid #ddd; padding: 0.5rem; text-align: left; }
        th { background-color: #f5f5f5; }
        .metadata { background: #f9f9f9; padding: 1rem; border-radius: 4px; }
        .metadata dt { font-weight: bold; }
        .metadata dd { margin-left: 1rem; margin-bottom: 0.5rem; }
        """
    }
}

// MARK: - Markdownエンジン

class RefactoredMarkdownExportEngine: BaseExportEngine {
    
    init() {
        super.init(
            engineName: "RefactoredMarkdownEngine",
            supportedFeatures: [.richText, .images, .tables, .hyperlinks],
            outputMimeType: "text/markdown"
        )
    }
    
    override func performExport(content: Any, options: Any) async throws -> ExportContent {
        let markdownContent = try await generateMarkdown(content: content, options: options)
        
        return ExportContent(
            data: Data(markdownContent.utf8),
            mimeType: outputMimeType
        )
    }
    
    private func generateMarkdown(content: Any, options: Any) async throws -> String {
        guard let documentContent = content as? ProjectDocumentContent else {
            throw ExportError.validationFailed([
                ExportValidationError(
                    field: "content",
                    message: "Expected ProjectDocumentContent",
                    severity: .error
                )
            ])
        }
        
        var markdown = "# \(documentContent.title)\n\n"
        
        if let subtitle = documentContent.subtitle {
            markdown += "\(subtitle)\n\n"
        }
        
        for section in documentContent.sections {
            markdown += try await convertSectionToMarkdown(section)
            markdown += "\n\n"
        }
        
        return markdown
    }
    
    private func convertSectionToMarkdown(_ section: DocumentSection) async throws -> String {
        var markdown = "## \(section.title)\n\n"
        
        switch section.content {
        case .richText(let elements):
            for element in elements {
                markdown += convertElementToMarkdown(element) + "\n\n"
            }
        case .plainText(let text):
            markdown += text + "\n\n"
        case .markdown(let markdownContent):
            markdown += markdownContent + "\n\n"
        case .html:
            // HTMLはMarkdownではサポートしない
            markdown += "*HTML content not supported in Markdown export*\n\n"
        }
        
        return markdown
    }
    
    private func convertElementToMarkdown(_ element: DocumentElement) -> String {
        switch element {
        case .heading(let text, let level):
            let prefix = String(repeating: "#", count: level + 2) // +2 because document title is h1, section is h2
            return "\(prefix) \(text)"
        case .paragraph(let text):
            return text
        case .list(let items, let ordered):
            if ordered {
                return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            } else {
                return items.map { "- \($0)" }.joined(separator: "\n")
            }
        case .table(let headers, let rows):
            return generateMarkdownTable(headers: headers, rows: rows)
        case .image(let url, let caption):
            return "![\(caption ?? "")](\(url.absoluteString))"
        case .separator:
            return "---"
        case .metadata(let data):
            return generateMetadataMarkdown(data)
        default:
            return ""
        }
    }
    
    private func generateMarkdownTable(headers: [String], rows: [[String]]) -> String {
        var table = "| " + headers.joined(separator: " | ") + " |\n"
        table += "| " + headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
        
        for row in rows {
            table += "| " + row.joined(separator: " | ") + " |\n"
        }
        
        return table
    }
    
    private func generateMetadataMarkdown(_ metadata: [String: Any]) -> String {
        var markdown = "**Metadata:**\n\n"
        for (key, value) in metadata {
            markdown += "- **\(key):** \(value)\n"
        }
        return markdown
    }
}

// MARK: - データエンジン

class RefactoredDataExportEngine: BaseExportEngine {
    
    init() {
        super.init(
            engineName: "RefactoredDataEngine",
            supportedFeatures: [.metadata, .compression],
            outputMimeType: "application/json"
        )
    }
    
    override func performExport(content: Any, options: Any) async throws -> ExportContent {
        let jsonData = try await generateJSONData(content: content, options: options)
        
        return ExportContent(
            data: jsonData,
            mimeType: outputMimeType
        )
    }
    
    private func generateJSONData(content: Any, options: Any) async throws -> Data {
        // TODO: コンテンツをJSONにシリアライズ
        let jsonObject: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "content": "Mock JSON export",
            "metadata": [:]
        ]
        
        return try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
    }
}

// MARK: - ZIPエンジン

class ZipExportEngine: BaseExportEngine {
    
    init() {
        super.init(
            engineName: "ZipEngine",
            supportedFeatures: [.compression],
            outputMimeType: "application/zip"
        )
    }
    
    override func performExport(content: Any, options: Any) async throws -> ExportContent {
        let zipData = try await createZipArchive(content: content, options: options)
        
        return ExportContent(
            data: zipData,
            mimeType: outputMimeType
        )
    }
    
    private func createZipArchive(content: Any, options: Any) async throws -> Data {
        // TODO: ZIPアーカイブを作成
        // 複数のファイルをまとめて圧縮
        return Data("Mock ZIP archive".utf8)
    }
}