import Foundation
import SwiftUI

// MARK: - Error Handling Capability Protocol

@MainActor
protocol ErrorHandlingCapable: ObservableObject {
    var errorMessage: String? { get set }
    var showError: Bool { get set }
}

extension ErrorHandlingCapable {
    func handleError(_ error: Error) {
        if let noteAIError = error as? NoteAIError {
            errorMessage = noteAIError.userMessage
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    func handleErrorWithCallback(_ error: Error, onComplete: (() -> Void)? = nil) {
        handleError(error)
        onComplete?()
    }
}

// MARK: - Loading State Capability Protocol

@MainActor
protocol LoadingStateCapable: ObservableObject {
    var isLoading: Bool { get set }
}

extension LoadingStateCapable {
    func withLoading<T>(_ operation: @escaping () async throws -> T) async -> T? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await operation()
        } catch {
            if let errorHandler = self as? ErrorHandlingCapable {
                errorHandler.handleError(error)
            }
            return nil
        }
    }
    
    func withLoadingNoReturn(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await operation()
        } catch {
            if let errorHandler = self as? ErrorHandlingCapable {
                errorHandler.handleError(error)
            }
        }
    }
}

// MARK: - Combined Capability Protocol

@MainActor
protocol ViewModelCapable: ErrorHandlingCapable, LoadingStateCapable {
    // ViewModelの基本機能を統合
}

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let errorMessage: String?
    let onDismiss: (() -> Void)?
    
    init(isPresented: Binding<Bool>, errorMessage: String?, onDismiss: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.errorMessage = errorMessage
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content
            .alert("エラー", isPresented: $isPresented) {
                Button("OK") {
                    onDismiss?()
                }
            } message: {
                Text(errorMessage ?? "不明なエラーが発生しました")
            }
    }
}

extension View {
    func errorAlert(
        isPresented: Binding<Bool>,
        errorMessage: String?,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(
            isPresented: isPresented,
            errorMessage: errorMessage,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Loading State Modifier

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
            
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.8))
                )
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "読み込み中...") -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}