import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255.0,
            green: Double((int >> 8) & 0xFF) / 255.0,
            blue: Double(int & 0xFF) / 255.0,
            opacity: 1
        )
    }
}

enum AppTheme {
    static let background = Color(hex: "DEDEDE")
    static let textPrimary = Color(hex: "222222")
    static let textSecondary = Color(hex: "939393")
    static let violetStart = Color(hex: "B163DB")
    static let violetEnd = Color(hex: "7530AD")
    static let accent = Color(hex: "A148D1")

    static var mainGradient: LinearGradient {
        LinearGradient(
            colors: [violetStart, violetEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PrimaryGradientButton: View {
    let title: String
    var icon: String? = nil
    var assetIcon: String? = nil
    var height: CGFloat = 60
    var width: CGFloat? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let assetIcon {
                Image(assetIcon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: width ?? .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppTheme.mainGradient)
                .shadow(color: Color(hex: "67008F").opacity(0.55), radius: 10)
        )
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var cornerRadius: CGFloat = 32

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.9), lineWidth: 1)
                    )
            )
    }
}
