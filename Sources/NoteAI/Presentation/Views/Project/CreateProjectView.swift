import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    let onProjectCreated: (String, String?, Data?) -> Void
    
    // MARK: - Computed Properties
    
    private var leadingPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .navigationBarLeading
        #else
        return .cancellationAction
        #endif
    }
    
    private var trailingPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // カバー画像選択
                    coverImageSection
                    
                    // プロジェクト情報入力
                    projectInfoSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("新しいプロジェクト")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: leadingPlacement) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: trailingPlacement) {
                    Button("作成") {
                        createProject()
                    }
                    .disabled(!canCreateProject || isCreating)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: selectedPhoto) { oldValue, newValue in
            Task {
                await loadSelectedPhoto()
            }
        }
    }
    
    // MARK: - Cover Image Section
    
    private var coverImageSection: some View {
        VStack(spacing: 16) {
            Text("カバー画像")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            coverImageView
            
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "photo")
                    Text(coverImageData != nil ? "画像を変更" : "画像を選択")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            
            if coverImageData != nil {
                Button("画像を削除") {
                    coverImageData = nil
                    selectedPhoto = nil
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
    
    private var coverImageView: some View {
        CoverImageView.fullWidth(imageData: coverImageData, height: 200)
    }
    
    // MARK: - Project Info Section
    
    private var projectInfoSection: some View {
        VStack(spacing: 20) {
            // プロジェクト名
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("プロジェクト名")
                        .font(.headline)
                    
                    Text("*")
                        .foregroundColor(.red)
                        .font(.headline)
                }
                
                TextField("プロジェクト名を入力", text: $projectName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isCreating)
                
                HStack {
                    Text("\(projectName.count)/\(AppConstants.Project.maxNameLength)")
                        .font(.caption)
                        .foregroundColor(projectName.count > AppConstants.Project.maxNameLength ? .red : .secondary)
                    
                    Spacer()
                }
            }
            
            // プロジェクト説明
            VStack(alignment: .leading, spacing: 8) {
                Text("説明")
                    .font(.headline)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $projectDescription)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(isCreating)
                    
                    if projectDescription.isEmpty {
                        Text("プロジェクトの説明を入力（省略可）")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                
                HStack {
                    Text("\(projectDescription.count)/\(AppConstants.Project.maxDescriptionLength)")
                        .font(.caption)
                        .foregroundColor(projectDescription.count > AppConstants.Project.maxDescriptionLength ? .red : .secondary)
                    
                    Spacer()
                }
            }
            
            // プロジェクト作成ボタン
            Button {
                createProject()
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus")
                    }
                    
                    Text(isCreating ? "作成中..." : "プロジェクトを作成")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canCreateProject && !isCreating ? Color.blue : Color.gray)
                )
            }
            .disabled(!canCreateProject || isCreating)
        }
    }
    
    // MARK: - Computed Properties
    
    private var canCreateProject: Bool {
        ValidationHelper.validateProjectName(projectName) &&
        ValidationHelper.validateProjectDescription(projectDescription)
    }
    
    // MARK: - Methods
    
    private func createProject() {
        guard canCreateProject else { return }
        
        isCreating = true
        
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
        
        Task {
            await MainActor.run {
                onProjectCreated(trimmedName, finalDescription, coverImageData)
                isCreating = false
                dismiss()
            }
        }
    }
    
    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhoto = selectedPhoto else { return }
        
        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self) {
                // 画像サイズを制限
                if !ValidationHelper.validateImageSize(data) {
                    errorMessage = "画像サイズが大きすぎます。\(AppConstants.Image.maxFileSize / (1024 * 1024))MB以下の画像を選択してください。"
                    showError = true
                    return
                }
                
                // 画像をリサイズ
                #if canImport(UIKit)
                if let uiImage = UIImage(data: data),
                   let resizedData = resizeImage(uiImage, maxSize: AppConstants.Image.maxDimensions) {
                    coverImageData = resizedData
                } else {
                    coverImageData = data
                }
                #else
                if let nsImage = NSImage(data: data),
                   let resizedData = resizeImage(nsImage, maxSize: AppConstants.Image.maxDimensions) {
                    coverImageData = resizedData
                } else {
                    coverImageData = data
                }
                #endif
            }
        } catch {
            errorMessage = "画像の読み込みに失敗しました。"
            showError = true
        }
    }
    
    #if canImport(UIKit)
    private func resizeImage(_ image: UIImage, maxSize: CGSize) -> Data? {
        let size = image.size
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height)
        
        if ratio >= 1.0 {
            return image.jpegData(compressionQuality: 0.8)
        }
        
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage?.jpegData(compressionQuality: AppConstants.Image.compressionQuality)
    }
    #else
    private func resizeImage(_ image: NSImage, maxSize: CGSize) -> Data? {
        let size = image.size
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height)
        
        if ratio >= 1.0 {
            return image.tiffRepresentation
        }
        
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return resizedImage.tiffRepresentation
    }
    #endif
}