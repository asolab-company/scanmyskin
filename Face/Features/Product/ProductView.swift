import SwiftUI
import UIKit

struct ProductView: View {
    let product: ScannedProduct
    private let isReportLocked: Bool
    private let onUnlock: (() -> Void)?
    let onBack: () -> Void
    let onToggleFavorite: (UUID) -> Void

    init(
        product: ScannedProduct,
        isLocked: Bool = false,
        onUnlock: (() -> Void)? = nil,
        onBack: @escaping () -> Void,
        onToggleFavorite: @escaping (UUID) -> Void
    ) {
        self.product = product
        self.isReportLocked = isLocked
        self.onUnlock = onUnlock
        self.onBack = onBack
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    heroImage

                    VStack(alignment: .leading, spacing: 0) {
                        topMeta
                            .padding(.top, 16)

                        Text(product.title)
                            .font(.system(size: 32 * 0.75, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.top, 16)

                        Text(product.brand)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 2)

                        if let analysis {
                            recommendationCard(analysis: analysis)
                                .padding(.top, 28)

                            if !analysis.isFaceProduct {
                                notFaceProductCard(analysis: analysis)
                                    .padding(.top, 16)
                            } else {
                                HStack(spacing: 14) {
                                    bulletCard(
                                        title: "Pros",
                                        tint: Color(hex: "0BAE79"),
                                        icon: "hand.thumbsup.fill",
                                        items: analysis.pros
                                    )
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    bulletCard(
                                        title: "Cons",
                                        tint: Color(hex: "F64F4F"),
                                        icon: "hand.thumbsdown.fill",
                                        items: analysis.cons
                                    )
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                .padding(.top, 14)

                                Text("Product Information")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color(hex: "161616"))
                                    .padding(.top, 24)

                                sectionHeader(title: "How To Use", tint: Color(hex: "039EFF"), icon: "questionmark.circle")
                                    .padding(.top, 24)

                                numberedCard(items: analysis.howToUse)
                                    .padding(.top, 12)

                                sectionHeader(title: "Warnings", tint: Color(hex: "FF8503"), icon: "exclamationmark.triangle")
                                    .padding(.top, 24)

                                warningCard(items: analysis.warnings)
                                    .padding(.top, 12)

                                sectionHeader(title: "Ingredients Analysis", tint: Color(hex: "039EFF"), icon: "questionmark.circle")
                                    .padding(.top, 24)

                                ingredientsCards(items: analysis.ingredients)
                                    .padding(.top, 12)
                            }
                        } else {
                            analysisUnavailableCard
                                .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 19)
                    .padding(.bottom, 24)
                    
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(isReportLocked ? 0.15 : 0))
                    )
                }
                .padding(.bottom, 24)
            }
            .background(VerticalScrollLockConfigurator())
        }
        .safeAreaInset(edge: .bottom) {
            if shouldShowUnlockButton {
                unlockButton
                    .padding(.horizontal, 19)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            HStack {
                Button(action: onBack) {
                    Circle()
                        .fill(Color.white.opacity(0.46))
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 19)
            .padding(.top)
        }
    }

    private var analysis: ProductAnalysis? {
        if case .completed(let completed) = product.analysisState {
            return completed
        }
        return nil
    }

    private var safeTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
    }

    @ViewBuilder
    private var heroImage: some View {
        if let image = UIImage(data: product.imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 393 + safeTopInset)
                .frame(maxWidth: .infinity)
                .clipped()
                .padding(.top, -safeTopInset)
        } else {
            Color.white.opacity(0.7)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color(hex: "9B9B9B"))
                }
                .frame(height: 393 + safeTopInset)
                .frame(maxWidth: .infinity)
                .clipped()
                .padding(.top, -safeTopInset)
        }
    }

    private var topMeta: some View {
        HStack {
            Text(product.category)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 20)
                .background(
                    Capsule()
                        .fill(AppTheme.accent.opacity(0.25))
                )

            Spacer()

            Button {
                onToggleFavorite(product.id)
            } label: {
                Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: "F192E4"))
            }
            .buttonStyle(.plain)
            .disabled(isReportLocked)
            .opacity(isReportLocked ? 0.4 : 1)
        }
    }

    private var shouldShowUnlockButton: Bool {
        isReportLocked && onUnlock != nil
    }

    private var unlockButton: some View {
        Button {
            onUnlock?()
        } label: {
            Text("Unlock Product Insights")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "B163DB"), Color(hex: "7530AD")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "67008F").opacity(0.74), radius: 10, x: 0, y: 0)
                )
        }
        .buttonStyle(.plain)
    }

    private func recommendationCard(analysis: ProductAnalysis) -> some View {
        let tint = recommendationTint(for: analysis.suitability)

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.96), tint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: tint.opacity(0.33), radius: 4, y: 4)

                Text("\(analysis.suitabilityScore)%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: recommendationIcon(for: analysis.suitability))
                        .font(.system(size: 18, weight: .semibold))
                    Text(recommendationTitle(for: analysis.suitability))
                        .font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(tint)

                Text(analysis.suitabilitySummary)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(tint, lineWidth: 2)
                )
        )
    }

    private func notFaceProductCard(analysis: ProductAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "F64F4F"))
                Text("Not a Face Product")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text(analysis.rejectionReason ?? "Please scan a supported head or face beauty product (face, lips, eyes, scalp or hair).")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
    }

    private var analysisUnavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis is unavailable for this item.")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Please return and run product analysis again.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
    }

    private func bulletCard(title: String, tint: Color, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                if items.isEmpty {
                    Text("No data.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(item)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                    }
                    .blur(radius: isReportLocked ? 5 : 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: 198, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
    }

    private func sectionHeader(title: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(tint)
                .frame(width: 2, height: 24)

            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()
        }
    }

    private func numberedCard(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if items.isEmpty {
                Text("No usage guidance was returned.")
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text("\(index + 1). \(item)")
                }.blur(radius: isReportLocked ? 5 : 0)
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
    }

    private func warningCard(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if items.isEmpty {
                warningLine("No specific warnings were returned.")
            } else {
                ForEach(items, id: \.self) { item in
                    warningLine(item)
                }.blur(radius: isReportLocked ? 5 : 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(hex: "F3E3A0"))
        )
    }

    private func warningLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "FF8503"))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ingredientsCards(items: [ProductIngredientAnalysis]) -> some View {
        VStack(spacing: 8) {
            if items.isEmpty {
                ingredientCard(
                    title: "No ingredient details",
                    subtitle: "OpenAI could not identify ingredients from this photo.",
                    badge: "UNKNOWN",
                    badgeColor: Color(hex: "9B9B9B")
                )
            } else {
                ForEach(items) { item in
                    ingredientCard(
                        title: item.name,
                        subtitle: item.details,
                        badge: ingredientBadgeTitle(item.verdict),
                        badgeColor: ingredientBadgeColor(item.verdict)
                    )
                }
            }
        }
    }

    private func ingredientCard(title: String, subtitle: String, badge: String, badgeColor: Color) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }.blur(radius: isReportLocked ? 5 : 0)

            Spacer(minLength: 8)

            Text(badge)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 16)
                .frame(height: 20)
                .background(
                    Capsule()
                        .fill(badgeColor.opacity(0.3))
                ).blur(radius: isReportLocked ? 5 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
    }

    private func recommendationTint(for suitability: ProductSuitability) -> Color {
        switch suitability {
        case .suitable:
            return Color(hex: "0BAE79")
        case .notSuitable:
            return Color(hex: "F64F4F")
        case .unknown:
            return Color(hex: "F64F4F")
        }
    }

    private func recommendationTitle(for suitability: ProductSuitability) -> String {
        switch suitability {
        case .suitable:
            return "Recommended"
        case .notSuitable:
            return "Not Recommended"
        case .unknown:
            return "Not Recommended"
        }
    }

    private func recommendationIcon(for suitability: ProductSuitability) -> String {
        switch suitability {
        case .suitable:
            return "hand.thumbsup.fill"
        case .notSuitable:
            return "hand.thumbsdown.fill"
        case .unknown:
            return "hand.thumbsdown.fill"
        }
    }

    private func ingredientBadgeTitle(_ verdict: ProductIngredientVerdict) -> String {
        switch verdict {
        case .safe:
            return "SAFE"
        case .caution:
            return "CAUTION"
        case .unsafe:
            return "UNSAFE"
        }
    }

    private func ingredientBadgeColor(_ verdict: ProductIngredientVerdict) -> Color {
        switch verdict {
        case .safe:
            return Color(hex: "0BAE79")
        case .caution:
            return Color(hex: "FF8503")
        case .unsafe:
            return Color(hex: "F64F4F")
        }
    }
}

private struct VerticalScrollLockConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        DispatchQueue.main.async {
            configureScrollView(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            configureScrollView(from: uiView)
        }
    }

    private func configureScrollView(from view: UIView) {
        guard let scrollView = findAncestorScrollView(from: view) else { return }
        scrollView.isDirectionalLockEnabled = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
    }

    private func findAncestorScrollView(from view: UIView) -> UIScrollView? {
        var candidate: UIView? = view
        while let current = candidate {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            candidate = current.superview
        }
        return nil
    }
}

#Preview("Product") {
    ProductView(product: .previewCompleted, onBack: {}, onToggleFavorite: { _ in })
}

#Preview("Product Locked") {
    ProductView(
        product: .previewCompleted,
        isLocked: true,
        onUnlock: {},
        onBack: {},
        onToggleFavorite: { _ in }
    )
}
