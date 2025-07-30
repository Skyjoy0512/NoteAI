import XCTest
@testable import NoteAI

final class NoteAITests: XCTestCase {
    func testExample() throws {
        // エクスポート機能の基本テスト
        let exportFormat = ExportFormat.pdf
        XCTAssertEqual(exportFormat.fileExtension, "pdf")
        
        let exportOptions = ExportOptions()
        XCTAssertTrue(exportOptions.includeMetadata)
        XCTAssertEqual(exportOptions.compressionLevel, .medium)
    }
    
    func testExportTypes() throws {
        // エクスポートタイプのテスト
        let projectType = ExportType.project
        XCTAssertEqual(projectType.rawValue, "project")
        
        let analysisType = ExportType.analysis
        XCTAssertEqual(analysisType.rawValue, "analysis")
    }
    
    func testExportFeatures() throws {
        // エクスポート機能のテスト
        let richTextFeature = ExportFeature.richText
        XCTAssertEqual(richTextFeature.rawValue, "rich_text")
        
        let chartsFeature = ExportFeature.charts
        XCTAssertEqual(chartsFeature.rawValue, "charts")
    }
}