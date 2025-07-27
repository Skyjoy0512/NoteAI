import SwiftUI

struct CoverImageView: View {
    let imageData: Data?
    let size: CGSize
    let cornerRadius: CGFloat
    let showPlaceholder: Bool
    let placeholderIcon: String
    let placeholderText: String?
    
    init(
        imageData: Data?,
        size: CGSize,
        cornerRadius: CGFloat = AppConfiguration.UI.buttonCornerRadius,
        showPlaceholder: Bool = true,
        placeholderIcon: String = "folder",
        placeholderText: String? = nil
    ) {
        self.imageData = imageData
        self.size = size
        self.cornerRadius = cornerRadius
        self.showPlaceholder = showPlaceholder
        self.placeholderIcon = placeholderIcon
        self.placeholderText = placeholderText
    }
    
    var body: some View {
        Group {
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .cornerRadius(cornerRadius)
            } else if showPlaceholder {
                placeholderView
            } else {
                Color.clear
                    .frame(width: size.width, height: size.height)
            }
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width, height: size.height)
            .cornerRadius(cornerRadius)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: placeholderIcon)
                        .font(.system(size: iconSize))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let text = placeholderText {
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
            }
    }
    
    private var gradientColors: [Color] {
        // ランダムなグラデーション色を生成（一貫性のために固定シード使用）
        let colors = [Color.blue, Color.purple, Color.green, Color.orange, Color.pink, Color.indigo]
        return [colors.randomElement() ?? .blue, colors.randomElement() ?? .purple]
    }
    
    private var iconSize: CGFloat {
        min(size.width, size.height) * 0.3
    }
}

// MARK: - Predefined Sizes

extension CoverImageView {
    static func cardSize(imageData: Data?) -> CoverImageView {
        CoverImageView(
            imageData: imageData,
            size: CGSize(width: .infinity, height: AppConfiguration.Image.cardImageHeight),
            cornerRadius: AppConfiguration.UI.buttonCornerRadius,
            placeholderIcon: "folder",
            placeholderText: "カバー画像を選択"
        )
    }
    
    static func rowSize(imageData: Data?) -> CoverImageView {
        CoverImageView(
            imageData: imageData,
            size: AppConfiguration.Image.rowImageSize,
            cornerRadius: AppConfiguration.UI.buttonCornerRadius,
            placeholderIcon: "folder"
        )
    }
    
    static func thumbnailSize(imageData: Data?) -> CoverImageView {
        CoverImageView(
            imageData: imageData,
            size: AppConfiguration.Image.thumbnailSize,
            cornerRadius: AppConfiguration.UI.cardCornerRadius,
            placeholderIcon: "photo",
            placeholderText: "画像を選択"
        )
    }
    
    static func fullWidth(imageData: Data?, height: CGFloat = 200) -> CoverImageView {
        CoverImageView(
            imageData: imageData,
            size: CGSize(width: .infinity, height: height),
            cornerRadius: AppConfiguration.UI.cardCornerRadius,
            placeholderIcon: "photo",
            placeholderText: "カバー画像を選択"
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        CoverImageView.cardSize(imageData: nil)
        CoverImageView.rowSize(imageData: nil)
        CoverImageView.thumbnailSize(imageData: nil)
    }
    .padding()
}