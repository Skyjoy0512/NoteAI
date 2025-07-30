import SwiftUI
import Combine
import Foundation

@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentRecording: Recording?
    @Published var recordingProgress: RecordingProgress?
    @Published var transcriptionProgress: TranscriptionProgress?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var selectedProject: Project?
    @Published var availableProjects: [Project] = []
    
    // MARK: - Recording Settings
    @Published var recordingSettings = RecordingSettings(
        quality: .high,
        language: "ja",
        format: .m4a
    )
    
    // Additional settings for UI
    @Published var audioQuality: AudioQuality = .high
    @Published var enableNoiseCancellation = true
    @Published var enableAutoTranscription = true
    @Published var enableAutoSave = false
    @Published var autoSaveInterval = 30
    
    // MARK: - Audio Level Monitoring
    @Published var audioLevel: Float = 0.0
    @Published var averageAudioLevel: Float = 0.0
    private var audioLevelTimer: Timer?
    
    // MARK: - Dependencies
    private let recordingUseCase: RecordingUseCaseProtocol
    private let transcriptionUseCase: TranscriptionUseCaseProtocol
    private let projectRepository: ProjectRepositoryProtocol
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init(
        recordingUseCase: RecordingUseCaseProtocol,
        transcriptionUseCase: TranscriptionUseCaseProtocol,
        projectRepository: ProjectRepositoryProtocol
    ) {
        self.recordingUseCase = recordingUseCase
        self.transcriptionUseCase = transcriptionUseCase
        self.projectRepository = projectRepository
        
        setupAudioLevelMonitoring()
        loadAvailableProjects()
    }
    
    deinit {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    // MARK: - Recording Control
    
    func startRecording() async {
        do {
            errorMessage = nil
            showError = false
            
            let recording = try await recordingUseCase.startRecording(
                projectId: selectedProject?.id,
                settings: recordingSettings
            )
            
            currentRecording = recording
            isRecording = true
            isPaused = false
            
            startProgressMonitoring()
            startAudioLevelMonitoring()
            
        } catch {
            await handleError(error)
        }
    }
    
    func pauseRecording() async {
        do {
            try await recordingUseCase.pauseRecording()
            isPaused = true
            stopAudioLevelMonitoring()
        } catch {
            await handleError(error)
        }
    }
    
    func resumeRecording() async {
        do {
            try await recordingUseCase.resumeRecording()
            isPaused = false
            startAudioLevelMonitoring()
        } catch {
            await handleError(error)
        }
    }
    
    func stopRecording() async {
        do {
            let finalRecording = try await recordingUseCase.stopRecording()
            
            currentRecording = finalRecording
            isRecording = false
            isPaused = false
            
            stopProgressMonitoring()
            stopAudioLevelMonitoring()
            
            // 自動文字起こし開始（ローカルWhisper）
            await startAutoTranscription(finalRecording)
            
        } catch {
            await handleError(error)
        }
    }
    
    func deleteRecording(_ recordingId: UUID) async {
        do {
            try await recordingUseCase.deleteRecording(recordingId)
            
            if currentRecording?.id == recordingId {
                currentRecording = nil
                isRecording = false
                isPaused = false
                stopProgressMonitoring()
                stopAudioLevelMonitoring()
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Transcription Control
    
    func startAutoTranscription(_ recording: Recording) async {
        do {
            transcriptionProgress = nil
            
            let result = try await transcriptionUseCase.transcribeRecording(
                recording,
                method: .local(.base)
            )
            
            // 文字起こし完了後、Recording更新
            if var updatedRecording = currentRecording {
                updatedRecording.transcription = result.text
                updatedRecording.updatedAt = Date()
                currentRecording = updatedRecording
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    func retranscribeWithAPI(_ provider: LLMProvider) async {
        guard let recording = currentRecording else { return }
        
        do {
            transcriptionProgress = nil
            
            let result = try await transcriptionUseCase.retranscribeWithAPI(
                recording,
                provider: provider
            )
            
            // API文字起こし完了後、Recording更新
            if var updatedRecording = currentRecording {
                updatedRecording.transcription = result.text
                updatedRecording.transcriptionMethod = .api(provider)
                updatedRecording.updatedAt = Date()
                currentRecording = updatedRecording
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    func cancelTranscription() async {
        guard let recordingId = currentRecording?.id else { return }
        
        do {
            try await transcriptionUseCase.cancelTranscription(for: recordingId)
            transcriptionProgress = nil
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Project Management
    
    func loadAvailableProjects() {
        Task {
            do {
                let projects = try await projectRepository.findAll()
                availableProjects = projects
            } catch {
                await handleError(error)
            }
        }
    }
    
    func selectProject(_ project: Project?) {
        selectedProject = project
    }
    
    // MARK: - Settings Management
    
    func updateRecordingSettings(_ settings: RecordingSettings) {
        recordingSettings = settings
    }
    
    func resetSettings() {
        recordingSettings = RecordingSettings(
            quality: .high,
            language: "ja",
            format: .m4a
        )
    }
    
    // MARK: - Progress Monitoring
    
    private func startProgressMonitoring() {
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRecordingProgress()
                self?.updateTranscriptionProgress()
            }
            .store(in: &cancellables)
    }
    
    private func stopProgressMonitoring() {
        cancellables.removeAll()
    }
    
    private func updateRecordingProgress() {
        recordingProgress = recordingUseCase.getRecordingProgress()
    }
    
    private func updateTranscriptionProgress() {
        guard let recordingId = currentRecording?.id else { return }
        transcriptionProgress = transcriptionUseCase.getTranscriptionProgress(for: recordingId)
    }
    
    // MARK: - Audio Level Monitoring
    
    private func setupAudioLevelMonitoring() {
        // 音声レベル監視の初期設定
    }
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updateAudioLevel()
            }
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    private func updateAudioLevel() {
        // TODO: AudioServiceから実際のレベルを取得
        // audioLevel = audioService.getCurrentLevel()
        
        // 平均レベル計算
        let smoothing: Float = 0.3
        averageAudioLevel = (averageAudioLevel * (1 - smoothing)) + (audioLevel * smoothing)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) async {
        errorMessage = error.localizedDescription
        showError = true
        
        // 録音中エラーの場合は録音を停止
        if isRecording {
            isRecording = false
            isPaused = false
            stopProgressMonitoring()
            stopAudioLevelMonitoring()
        }
    }
    
    // MARK: - Utility Methods
    
    var canStartRecording: Bool {
        !isRecording
    }
    
    var canPauseRecording: Bool {
        isRecording && !isPaused
    }
    
    var canResumeRecording: Bool {
        isRecording && isPaused
    }
    
    var canStopRecording: Bool {
        isRecording
    }
    
    var canTranscribe: Bool {
        currentRecording != nil && transcriptionProgress == nil
    }
    
    var isTranscribing: Bool {
        transcriptionProgress != nil
    }
    
    var formattedDuration: String {
        guard let progress = recordingProgress else { return "00:00:00" }
        return progress.formattedDuration
    }
    
    var formattedFileSize: String {
        guard let progress = recordingProgress else { return "0 KB" }
        return progress.formattedFileSize
    }
    
    var audioLevelPercentage: Double {
        Double(audioLevel) * 100
    }
    
    var averageAudioLevelPercentage: Double {
        Double(averageAudioLevel) * 100
    }
}