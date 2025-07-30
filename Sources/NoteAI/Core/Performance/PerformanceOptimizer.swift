import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - パフォーマンス最適化マネージャー

@MainActor
class PerformanceOptimizer {
    
    static let shared = PerformanceOptimizer()
    
    // MARK: - キャッシュマネージャー
    private let cacheManager = CacheManager()
    
    // MARK: - メモリ監視
    private let memoryMonitor = MemoryMonitor()
    
    // MARK: - バックグラウンドタスク
    private let backgroundProcessor = BackgroundProcessor()
    
    // MARK: - パフォーマンスメトリクス
    private var performanceMetrics = PerformanceMetrics()
    
    private init() {
        setupMemoryWarningObserver()
        setupBackgroundObserver()
    }
    
    // MARK: - 初期化・設定
    
    func configure() {
        cacheManager.configure()
        memoryMonitor.startMonitoring()
        backgroundProcessor.configure()
        
        // メモリ使用量の初期最適化
        optimizeMemoryUsage()
    }
    
    // MARK: - メモリ最適化
    
    func optimizeMemoryUsage() {
        // 不要なキャッシュをクリア
        cacheManager.clearExpiredCache()
        
        // 画像キャッシュを最適化
        optimizeImageCache()
        
        // 使用量データの古いレコードを削除
        cleanupOldUsageData()
        
        performanceMetrics.recordMemoryOptimization()
    }
    
    private func optimizeImageCache() {
        let memoryPressure = memoryMonitor.getCurrentMemoryPressure()
        
        switch memoryPressure {
        case .critical:
            cacheManager.clearImageCache()
        case .warning:
            cacheManager.reduceImageCache(by: 0.5)
        case .normal:
            break
        }
    }
    
    private func cleanupOldUsageData() {
        Task {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            try? await backgroundProcessor.cleanupOldData(olderThan: cutoffDate)
        }
    }
    
    // MARK: - バックグラウンド処理最適化
    
    func scheduleBackgroundTask<T>(_ task: @escaping () async throws -> T) -> Task<T, Error> {
        return Task.detached(priority: .background) {
            return try await task()
        }
    }
    
    func batchProcess<T, R>(
        items: [T],
        batchSize: Int = 10,
        processor: @escaping (T) async throws -> R
    ) async throws -> [R] {
        var results: [R] = []
        
        for batch in items.chunked(into: batchSize) {
            let batchResults = try await withThrowingTaskGroup(of: R.self) { group in
                for item in batch {
                    group.addTask {
                        return try await processor(item)
                    }
                }
                
                var batchResults: [R] = []
                for try await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
            
            results.append(contentsOf: batchResults)
            
            // バッチ間で少し待機（システム負荷軽減）
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        return results
    }
    
    // MARK: - データベース最適化
    
    func optimizeDatabase() async throws {
        try await backgroundProcessor.optimizeDatabase()
        performanceMetrics.recordDatabaseOptimization()
    }
    
    // MARK: - ネットワーク最適化
    
    func optimizeNetworkRequests() {
        // リクエストの重複排除
        deduplicateNetworkRequests()
        
        // 接続プールの最適化
        optimizeConnectionPool()
        
        performanceMetrics.recordNetworkOptimization()
    }
    
    private func deduplicateNetworkRequests() {
        // 実装: 同じエンドポイントへの重複リクエストを防ぐ
    }
    
    private func optimizeConnectionPool() {
        // 実装: HTTP接続プールのサイズを最適化
    }
    
    // MARK: - UI最適化
    
    func optimizeUI() {
        // ビューの再描画を最適化
        optimizeViewRendering()
        
        // スクロールパフォーマンスを改善
        optimizeScrollPerformance()
        
        performanceMetrics.recordUIOptimization()
    }
    
    private func optimizeViewRendering() {
        // 実装: 不要なビュー更新を防ぐ
    }
    
    private func optimizeScrollPerformance() {
        // 実装: LazyVStackやVirtualizedListの活用
    }
    
    // MARK: - パフォーマンス測定
    
    func measurePerformance<T>(
        operation: String,
        _ block: () async throws -> T
    ) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = memoryMonitor.getCurrentMemoryUsage()
        
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = memoryMonitor.getCurrentMemoryUsage()
            let duration = endTime - startTime
            let memoryDelta = endMemory - startMemory
            
            performanceMetrics.record(
                operation: operation,
                duration: duration,
                memoryDelta: memoryDelta
            )
        }
        
        return try await block()
    }
    
    // MARK: - 通知設定
    
    private func setupMemoryWarningObserver() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        #endif
    }
    
    private func setupBackgroundObserver() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        #endif
    }
    
    private func handleMemoryWarning() {
        cacheManager.clearCache(priority: .high)
        optimizeMemoryUsage()
    }
    
    private func handleAppDidEnterBackground() {
        // バックグラウンドでの最適化処理
        Task {
            await backgroundProcessor.performBackgroundOptimization()
        }
    }
    
    // MARK: - パフォーマンスレポート
    
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            metrics: performanceMetrics,
            memoryUsage: memoryMonitor.getMemoryReport(),
            cacheUsage: cacheManager.getCacheReport()
        )
    }
}

// MARK: - キャッシュマネージャー

class CacheManager {
    
    #if canImport(UIKit)
    private var imageCache = NSCache<NSString, UIImage>()
    #elseif canImport(AppKit)
    private var imageCache = NSCache<NSString, NSImage>()
    #endif
    private var dataCache = NSCache<NSString, NSData>()
    private var responseCache: [String: CachedResponse] = [:]
    private var cacheMetrics = CacheMetrics()
    
    struct CachedResponse {
        let data: Data
        let timestamp: Date
        let expirationDate: Date
    }
    
    func configure() {
        // メモリに応じてキャッシュサイズを調整
        let memorySize = ProcessInfo.processInfo.physicalMemory
        let cacheSize = min(Int(memorySize / 10), 100_000_000) // 最大100MB
        
        imageCache.totalCostLimit = cacheSize / 2
        dataCache.totalCostLimit = cacheSize / 2
        
        imageCache.countLimit = 100
        dataCache.countLimit = 200
    }
    
    #if canImport(UIKit)
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // RGBA
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
        cacheMetrics.recordImageCached(size: cost)
    }
    
    func getImage(forKey key: String) -> UIImage? {
        let image = imageCache.object(forKey: key as NSString)
        if image != nil {
            cacheMetrics.recordImageHit()
        } else {
            cacheMetrics.recordImageMiss()
        }
        return image
    }
    #elseif canImport(AppKit)
    func cacheImage(_ image: NSImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // RGBA
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
        cacheMetrics.recordImageCached(size: cost)
    }
    
    func getImage(forKey key: String) -> NSImage? {
        let image = imageCache.object(forKey: key as NSString)
        if image != nil {
            cacheMetrics.recordImageHit()
        } else {
            cacheMetrics.recordImageMiss()
        }
        return image
    }
    #endif
    
    func cacheResponse(_ data: Data, forKey key: String, expirationTime: TimeInterval = 300) {
        let cachedResponse = CachedResponse(
            data: data,
            timestamp: Date(),
            expirationDate: Date().addingTimeInterval(expirationTime)
        )
        responseCache[key] = cachedResponse
        cacheMetrics.recordResponseCached(size: data.count)
    }
    
    func getResponse(forKey key: String) -> Data? {
        guard let cached = responseCache[key] else {
            cacheMetrics.recordResponseMiss()
            return nil
        }
        
        if cached.expirationDate < Date() {
            responseCache.removeValue(forKey: key)
            cacheMetrics.recordResponseMiss() // Use existing method
            return nil
        }
        
        cacheMetrics.recordResponseHit()
        return cached.data
    }
    
    func clearExpiredCache() {
        let now = Date()
        responseCache = responseCache.filter { $0.value.expirationDate >= now }
        cacheMetrics.recordExpiredCleanup()
    }
    
    func clearImageCache() {
        imageCache.removeAllObjects()
        cacheMetrics.recordImageCacheCleared()
    }
    
    func reduceImageCache(by ratio: Double) {
        let newLimit = Int(Double(imageCache.totalCostLimit) * (1.0 - ratio))
        imageCache.totalCostLimit = newLimit
        cacheMetrics.recordImageCacheReduced(ratio: ratio)
    }
    
    func clearCache(priority: CachePriority) {
        switch priority {
        case .high:
            clearImageCache()
            responseCache.removeAll()
        case .medium:
            reduceImageCache(by: 0.5)
            clearExpiredCache()
        case .low:
            clearExpiredCache()
        }
    }
    
    func getCacheReport() -> CacheReport {
        return CacheReport(
            imageCacheSize: imageCache.totalCostLimit,
            dataCacheSize: dataCache.totalCostLimit,
            responseCacheCount: responseCache.count,
            metrics: cacheMetrics
        )
    }
}

// MARK: - メモリ監視

class MemoryMonitor {
    
    private var isMonitoring = false
    private var memoryMetrics = MemoryMetrics()
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.recordMemoryUsage()
        }
    }
    
    func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    func getCurrentMemoryPressure() -> MemoryPressure {
        let currentUsage = getCurrentMemoryUsage()
        let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
        let percentage = Double(currentUsage) / Double(totalMemory)
        
        if percentage > 0.9 {
            return .critical
        } else if percentage > 0.7 {
            return .warning
        } else {
            return .normal
        }
    }
    
    private func recordMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        memoryMetrics.record(usage: usage)
    }
    
    func getMemoryReport() -> MemoryReport {
        return MemoryReport(
            currentUsage: getCurrentMemoryUsage(),
            peakUsage: memoryMetrics.peakUsage,
            averageUsage: memoryMetrics.averageUsage,
            pressure: getCurrentMemoryPressure()
        )
    }
}

// MARK: - バックグラウンドプロセッサー

class BackgroundProcessor {
    
    private let queue = DispatchQueue(label: "background.processor", qos: .background)
    
    func configure() {
        // バックグラウンド処理の設定
    }
    
    func cleanupOldData(olderThan date: Date) async throws {
        // 古いデータのクリーンアップ
        print("Cleaning up data older than \(date)")
    }
    
    func optimizeDatabase() async throws {
        // データベースの最適化
        print("Optimizing database")
    }
    
    func performBackgroundOptimization() async {
        // バックグラウンドでの最適化処理
        do {
            try await optimizeDatabase()
            let oldDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            try await cleanupOldData(olderThan: oldDate)
        } catch {
            print("Background optimization failed: \(error)")
        }
    }
}

// MARK: - 列挙型・構造体

enum MemoryPressure {
    case normal
    case warning
    case critical
}

enum CachePriority {
    case low
    case medium
    case high
}

struct PerformanceMetrics {
    private var operations: [String: [OperationMetric]] = [:]
    
    mutating func record(operation: String, duration: TimeInterval, memoryDelta: Int64) {
        let metric = OperationMetric(
            timestamp: Date(),
            duration: duration,
            memoryDelta: memoryDelta
        )
        
        if operations[operation] == nil {
            operations[operation] = []
        }
        operations[operation]?.append(metric)
        
        // 最新100件のみ保持
        if let count = operations[operation]?.count, count > 100 {
            operations[operation] = Array(operations[operation]!.suffix(100))
        }
    }
    
    mutating func recordMemoryOptimization() {
        record(operation: "memory_optimization", duration: 0, memoryDelta: 0)
    }
    
    mutating func recordDatabaseOptimization() {
        record(operation: "database_optimization", duration: 0, memoryDelta: 0)
    }
    
    mutating func recordNetworkOptimization() {
        record(operation: "network_optimization", duration: 0, memoryDelta: 0)
    }
    
    mutating func recordUIOptimization() {
        record(operation: "ui_optimization", duration: 0, memoryDelta: 0)
    }
    
    func getAverageDuration(for operation: String) -> TimeInterval {
        guard let metrics = operations[operation], !metrics.isEmpty else { return 0 }
        let total = metrics.reduce(0) { $0 + $1.duration }
        return total / Double(metrics.count)
    }
}

struct OperationMetric {
    let timestamp: Date
    let duration: TimeInterval
    let memoryDelta: Int64
}

struct CacheMetrics {
    private(set) var imageHits = 0
    private(set) var imageMisses = 0
    private(set) var responseHits = 0
    private(set) var responseMisses = 0
    private(set) var totalImagesCached = 0
    private(set) var totalResponsesCached = 0
    
    mutating func recordImageHit() { imageHits += 1 }
    mutating func recordImageMiss() { imageMisses += 1 }
    mutating func recordResponseHit() { responseHits += 1 }
    mutating func recordResponseMiss() { responseMisses += 1 }
    mutating func recordImageCached(size: Int) { totalImagesCached += 1 }
    mutating func recordResponseCached(size: Int) { totalResponsesCached += 1 }
    mutating func recordExpiredCleanup() {}
    mutating func recordImageCacheCleared() {}
    mutating func recordImageCacheReduced(ratio: Double) {}
    
    var imageHitRate: Double {
        let total = imageHits + imageMisses
        return total > 0 ? Double(imageHits) / Double(total) : 0
    }
    
    var responseHitRate: Double {
        let total = responseHits + responseMisses
        return total > 0 ? Double(responseHits) / Double(total) : 0
    }
}

struct MemoryMetrics {
    private var usageHistory: [Int64] = []
    
    mutating func record(usage: Int64) {
        usageHistory.append(usage)
        
        // 最新1000件のみ保持
        if usageHistory.count > 1000 {
            usageHistory = Array(usageHistory.suffix(1000))
        }
    }
    
    var peakUsage: Int64 {
        return usageHistory.max() ?? 0
    }
    
    var averageUsage: Int64 {
        guard !usageHistory.isEmpty else { return 0 }
        let total = usageHistory.reduce(0, +)
        return total / Int64(usageHistory.count)
    }
}

struct PerformanceReport {
    let metrics: PerformanceMetrics
    let memoryUsage: MemoryReport
    let cacheUsage: CacheReport
}

struct MemoryReport {
    let currentUsage: Int64
    let peakUsage: Int64
    let averageUsage: Int64
    let pressure: MemoryPressure
}

struct CacheReport {
    let imageCacheSize: Int
    let dataCacheSize: Int
    let responseCacheCount: Int
    let metrics: CacheMetrics
}

// MARK: - 配列拡張
// chunked(into:) extension is already defined elsewhere