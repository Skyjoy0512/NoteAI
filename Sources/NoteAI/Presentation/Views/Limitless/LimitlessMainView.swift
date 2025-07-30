import SwiftUI

// MARK: - ConnectionStatus Extensions

extension DeviceConnectionStatus {
    var displayName: String {
        switch self {
        case .disconnected:
            return "未接続"
        case .connecting:
            return "接続中"
        case .connected:
            return "接続済み"
        case .error(let message):
            return "エラー: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Limitlessメイン画面

struct LimitlessMainView: View {
    @StateObject private var settings = LimitlessSettings.shared
    @StateObject private var deviceService = LimitlessDeviceService()
    @State private var displayMode: DisplayMode = .lifelog
    @State private var showingSettings = false
    @State private var currentError: LimitlessError?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Display Mode Selector
                DisplayModeSelector(
                    selectedMode: $displayMode,
                    settings: settings
                )
                
                // Content View
                contentView
            }
            .navigationTitle("Limitless")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    DeviceStatusIndicator(
                        deviceService: deviceService,
                        onTap: { showingSettings = true }
                    )
                }
            }
            .sheet(isPresented: $showingSettings) {
                LimitlessSettingsView(
                    deviceService: deviceService
                )
            }
            .showError($currentError)
            .onAppear {
                displayMode = settings.defaultDisplayMode
            }
            .onChange(of: settings.defaultDisplayMode) { _, newMode in
                displayMode = newMode
            }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        switch displayMode {
        case .lifelog:
            LifelogView()
                .transition(.limitlessTransition(direction: .leading))
                
        case .audioFiles:
            AudioFilesListView()
                .transition(.limitlessTransition(direction: .trailing))
        }
    }
}

// MARK: - Display Mode Selector

struct DisplayModeSelector: View {
    @Binding var selectedMode: DisplayMode
    let settings: LimitlessSettings
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    DisplayModeButton(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedMode = mode
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            
            Divider()
        }
    }
}

struct DisplayModeButton: View {
    let mode: DisplayMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .imageScale(.medium)
                
                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName)モード")
        .accessibilityHint(isSelected ? "選択中" : "タップして切り替え")
    }
}

// MARK: - Device Status Indicator

struct DeviceStatusIndicator: View {
    @ObservedObject var deviceService: LimitlessDeviceService
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                statusIndicator
                
                if let device = deviceService.connectedDevice {
                    deviceInfo(device)
                } else {
                    Text(deviceService.connectionStatus.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("デバイス状態: \(deviceService.connectionStatus.displayName)")
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 4)
                    .scaleEffect(deviceService.connectionStatus == .connecting ? 1.5 : 1.0)
                    .opacity(deviceService.connectionStatus == .connecting ? 0 : 1)
                    .animation(
                        deviceService.connectionStatus == .connecting
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                        value: deviceService.connectionStatus
                    )
            )
    }
    
    @ViewBuilder
    private func deviceInfo(_ device: LimitlessDevice) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(device.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                batteryIndicator(device.batteryLevel)
                
                signalIndicator(device.signalStrength)
            }
        }
    }
    
    @ViewBuilder
    private func batteryIndicator(_ level: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: batteryIcon(level))
                .font(.caption2)
                .foregroundColor(batteryColor(level))
            
            Text("\(level)%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func signalIndicator(_ strength: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { bar in
                Rectangle()
                    .frame(width: 2, height: CGFloat(bar * 2))
                    .foregroundColor(bar <= strength ? .green : .gray.opacity(0.3))
            }
        }
    }
    
    private var statusColor: Color {
        switch deviceService.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 0...20:
            return "battery.25"
        case 21...50:
            return "battery.50"
        case 51...75:
            return "battery.75"
        default:
            return "battery.100"
        }
    }
    
    private func batteryColor(_ level: Int) -> Color {
        switch level {
        case 0...20:
            return .red
        case 21...50:
            return .orange
        default:
            return .green
        }
    }
}

// MARK: - Limitless Settings View (Refactored)

struct LimitlessSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var deviceService: LimitlessDeviceService
    @StateObject private var settings = LimitlessSettings.shared
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                deviceSection
                recordingSection
                displaySection
                storageSection
                advancedSection
                aboutSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var deviceSection: some View {
        Section("デバイス") {
            DeviceConnectionRow(deviceService: deviceService)
            
            if let device = deviceService.connectedDevice {
                DeviceInfoRows(device: device)
            }
        }
    }
    
    private var recordingSection: some View {
        Section("録音設定") {
            Picker("録音品質", selection: $settings.recordingQuality) {
                ForEach(RecordingQuality.allCases, id: \.self) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            
            Toggle("自動処理", isOn: $settings.autoProcessingEnabled)
            Toggle("バッテリー最適化", isOn: $settings.batteryOptimizationEnabled)
        }
    }
    
    private var displaySection: some View {
        Section("表示設定") {
            Picker("デフォルト表示", selection: $settings.defaultDisplayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }
    }
    
    private var storageSection: some View {
        Section("ストレージ") {
            Toggle("自動クリーンアップ", isOn: $settings.autoCleanupEnabled)
            
            Stepper(
                "保存期間: \(settings.retentionDays)日",
                value: $settings.retentionDays,
                in: 1...365
            )
            
            Button("今すぐクリーンアップ") {
                // Implement cleanup
            }
            .foregroundColor(.blue)
        }
    }
    
    private var advancedSection: some View {
        Section("詳細設定") {
            NavigationLink("音声品質") {
                AudioQualitySettingsView(settings: settings)
            }
            
            NavigationLink("エクスポート設定") {
                ExportSettingsView()
            }
            
            NavigationLink("プライバシー") {
                PrivacySettingsView()
            }
            
            Button("設定をリセット") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
        }
    }
    
    private var aboutSection: some View {
        Section("情報") {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("ビルド")
                Spacer()
                Text("2024.01.27")
                    .foregroundColor(.secondary)
            }
            
            Link("サポート", destination: URL(string: "https://support.example.com")!)
            Link("プライバシーポリシー", destination: URL(string: "https://privacy.example.com")!)
        }
    }
}

// MARK: - Supporting Views

struct DeviceConnectionRow: View {
    @ObservedObject var deviceService: LimitlessDeviceService
    
    var body: some View {
        HStack {
            Text("接続状態")
            
            Spacer()
            
            Text(deviceService.connectionStatus.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(deviceService.connectionStatus.color).opacity(0.1))
                .foregroundColor(Color(deviceService.connectionStatus.color))
                .cornerRadius(4)
        }
    }
}

struct DeviceInfoRows: View {
    let device: LimitlessDevice
    
    var body: some View {
        Group {
            HStack {
                Text("デバイス名")
                Spacer()
                Text(device.name)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("ファームウェア")
                Spacer()
                Text(device.firmwareVersion)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("バッテリー")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "battery.100")
                        .foregroundColor(.green)
                    Text("\(device.batteryLevel)%")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct AudioQualitySettingsView: View {
    @ObservedObject var settings: LimitlessSettings
    
    var body: some View {
        Form {
            Section("録音品質") {
                ForEach(RecordingQuality.allCases, id: \.self) { quality in
                    QualityRow(
                        quality: quality,
                        isSelected: settings.recordingQuality == quality,
                        action: { settings.recordingQuality = quality }
                    )
                }
            }
            
            Section("品質説明") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("録音品質による違い:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(RecordingQuality.allCases, id: \.self) { quality in
                        QualityDescription(quality: quality)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("音声品質")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QualityRow: View {
    let quality: RecordingQuality
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(quality.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("\(quality.sampleRate)Hz, \(quality.bitRate)kbps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct QualityDescription: View {
    let quality: RecordingQuality
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(quality.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var description: String {
        switch quality {
        case .low:
            return "バッテリー優先。長時間録音に適している。"
        case .medium:
            return "バランスの取れた品質。日常使用に最適。"
        case .high:
            return "高品質録音。重要な会議や講演に。"
        case .lossless:
            return "最高品質。音楽や専門的な用途に。"
        }
    }
}

struct ExportSettingsView: View {
    var body: some View {
        Form {
            Section("エクスポート形式") {
                Text("エクスポート設定の実装")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("エクスポート設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section("プライバシー設定") {
                Text("プライバシー設定の実装")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("プライバシー設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Custom Transitions

extension AnyTransition {
    static func limitlessTransition(direction: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction).combined(with: .opacity),
            removal: .move(edge: direction.opposite).combined(with: .opacity)
        )
    }
}

extension Edge {
    var opposite: Edge {
        switch self {
        case .leading: return .trailing
        case .trailing: return .leading
        case .top: return .bottom
        case .bottom: return .top
        }
    }
}

#Preview {
    LimitlessMainView()
}