import SwiftUI
import UIKit

enum HomeMode {
    case empty
    case filled
}

struct HomeView: View {
    let mode: HomeMode
    let report: SkinReport?
    let favoriteProducts: [ScannedProduct]
    var onStartScan: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    var onViewAllAnalysis: (() -> Void)? = nil
    var onOpenLatestReport: (() -> Void)? = nil
    var onOpenFavoriteProduct: ((ScannedProduct) -> Void)? = nil
    var onRemoveFavoriteProduct: ((ScannedProduct) -> Void)? = nil

    @AppStorage(AppData.StorageKeys.userName) private var storedUserName = ""

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    ctaCard
                        .padding(.top, 24)
                }
                .padding(.horizontal, 19)
              

                switch mode {
                case .empty:
                    Spacer(minLength: 0)

                    emptyState
                        .padding(.horizontal, 19)

                    Spacer(minLength: 0)
                    Color.clear
                        .frame(height: 130)
                case .filled:
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            if report != nil {
                                sectionTitle(
                                    "Skin Analysis",
                                    icon: "app_ic_facev",
                                    trailing: "View All",
                                    onTrailingTap: onViewAllAnalysis,
                                    onTitleTap: onOpenLatestReport
                                )

                                analysisCard
                                    .padding(.top, 16)
                            }

                            sectionTitle("Favorite", icon: "app_ic_like", trailing: nil, markerColor: Color(hex: "F192E4"))
                                .padding(.top, report == nil ? 0 : 24)

                            favoriteSection
                                .padding(.top, 16)
                        }
                        .padding(.horizontal, 19)
                        .padding(.top, 32)
                        .padding(.bottom, 130)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Hello, \(displayName)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Track your beauty jorney")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button {
                onOpenSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "565656"))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.46))
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    )
            }
        }
    }

    private var ctaCard: some View {
        Button {
            onStartScan?()
        } label: {
            HStack(spacing: 16) {
    
              
                    Image("app_ic_face")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                
              

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Analysis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Scan your face")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 82)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppTheme.mainGradient)
                    .shadow(color: Color(hex: "67008F").opacity(0.55), radius: 10)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image("app_ic_coach")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)

            Text("Start Your Analysis")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Take a face scan to get\npersonalized skin insights and\nrecommendations")
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                onStartScan?()
            } label: {
                PrimaryGradientButton(title: "Get Started", assetIcon: "app_ic_facev", width: 252)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private func sectionTitle(
        _ title: String,
        icon: String,
        trailing: String?,
        markerColor: Color = Color(hex: "C179FF"),
        onTrailingTap: (() -> Void)? = nil,
        onTitleTap: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(markerColor)
                .frame(width: 2, height: 24)
            if let onTitleTap {
                Button(action: onTitleTap) {
                    HStack(spacing: 8) {
                        Image(icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Image(icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
            if let trailing {
                if let onTrailingTap {
                    Button(action: onTrailingTap) {
                        Text(trailing)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(trailing)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var analysisCard: some View {
        let report = report ?? .placeholder

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    scoreBadge(score: report.overallScore)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(report.overallTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(report.overallSubtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Last analyzed: \(reportDate(report.createdAt))")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "BFBFBF"))
                    }
                }

                ForEach(homeMetrics(from: report)) { metric in
                    HomeMetricRow(metric: metric)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenLatestReport?()
        }
    }

    @ViewBuilder
    private var favoriteSection: some View {
        if favoriteProducts.isEmpty {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .frame(height: 84)
                .overlay {
                    Text("No favorites yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favoriteProducts) { product in
                        favoriteCard(product: product)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .frame(height: 215)
        }
    }

    private func favoriteCard(product: ScannedProduct) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                favoriteThumbnail(for: product)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    Button {
                        onRemoveFavoriteProduct?(product)
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color(hex: "F192E4"))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    if product.canOpenDetails {
                        Image(systemName: product.recommendationSymbolName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(hex: product.recommendationColorHex))
                            .frame(width: 32, height: 32)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(product.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "222222"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 116, height: 36, alignment: .topLeading)

                Text(product.brand)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "939393"))
                    .lineLimit(1)
                    .frame(width: 116, alignment: .leading)
            }
            .padding(.leading, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .frame(width: 148, height: 211, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.99), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenFavoriteProduct?(product)
        }
    }

    @ViewBuilder
    private func favoriteThumbnail(for product: ScannedProduct) -> some View {
        if let image = UIImage(data: product.imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 116, height: 116)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .frame(width: 116, height: 116)
        }
    }

    private func scoreBadge(score: Int) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFBF00"), Color(hex: "FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                .shadow(color: Color(hex: "FF8C00").opacity(0.45), radius: 4, y: 2)

            Text("\(score)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
    }

    private func homeMetrics(from report: SkinReport) -> [HomeMetric] {
        let metricsByID = Dictionary(uniqueKeysWithValues: report.metrics.map { ($0.id, $0) })
        let placeholderByID = Dictionary(uniqueKeysWithValues: SkinReport.placeholder.metrics.map { ($0.id, $0) })

        struct HomeMetricStyle {
            let title: String
            let id: String
            let fallbackID: String?
            let colorHex: String
        }

        let style: [HomeMetricStyle] = [
            .init(title: "Acne", id: "acne", fallbackID: nil, colorHex: "F64F4F"),
            .init(title: "Radiance", id: "radiance", fallbackID: nil, colorHex: "FFC803"),
            .init(title: "Texture", id: "texture", fallbackID: "melanin", colorHex: "0BAE79"),
            .init(title: "Pores", id: "pores", fallbackID: nil, colorHex: "039EFF"),
            .init(title: "Wrinkles", id: "wrinkles", fallbackID: nil, colorHex: "C179FF"),
            .init(title: "Hydration", id: "hydration", fallbackID: nil, colorHex: "F192E4")
        ]

        return style.compactMap { item in
            let metric = metricsByID[item.id]
                ?? item.fallbackID.flatMap { metricsByID[$0] }
                ?? placeholderByID[item.id]
                ?? item.fallbackID.flatMap { placeholderByID[$0] }

            guard let metric else { return nil }

            return HomeMetric(
                title: item.title,
                valueText: "\(metric.score) / 100",
                progress: CGFloat(max(0, min(100, metric.score))) / 100,
                color: Color(hex: item.colorHex)
            )
        }
    }

    private func reportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private var displayName: String {
        let trimmed = storedUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed
    }
}

struct HomeBottomNavigation: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            navButton(tab: .home, title: "Home", systemIcon: nil, assetIcon: "app_ic_menu")
            navButton(tab: .scan, title: "Scan", systemIcon: nil, assetIcon: "app_ic_scan")
            navButton(tab: .coach, title: "AI Chat", systemIcon: nil, assetIcon: "app_ic_chat")
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        )
    }

    @ViewBuilder
    private func tabIcon(systemIcon: String?, assetIcon: String?, isActive: Bool) -> some View {
        if let assetIcon {
            Image(assetIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundStyle(isActive ? .white : Color(hex: "9B9B9B"))
        } else if let systemIcon {
            Image(systemName: systemIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isActive ? .white : Color(hex: "9B9B9B"))
        }
    }

    private func navButton(tab: MainTab, title: String, systemIcon: String?, assetIcon: String?) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Group {
                if selectedTab == tab {
                    HStack(spacing: 10) {
                        tabIcon(systemIcon: systemIcon, assetIcon: assetIcon, isActive: true)
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 124, height: 32)
                    .background(
                        Capsule()
                            .fill(AppTheme.mainGradient)
                            .shadow(color: Color(hex: "964CC4").opacity(0.29), radius: 6)
                    )
                } else {
                    tabIcon(systemIcon: systemIcon, assetIcon: assetIcon, isActive: false)
                        .frame(width: 36, height: 36)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeMetric: Identifiable {
    let id = UUID()
    let title: String
    let valueText: String
    let progress: CGFloat
    let color: Color
}

private struct HomeMetricRow: View {
    let metric: HomeMetric

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(metric.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(metric.valueText)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(metric.color)
                        .frame(width: proxy.size.width * metric.progress)
                }
            }
            .frame(height: 4)
        }
    }
}

struct SkinAnalysisHistoryView: View {
    let reports: [SkinReport]
    let onBack: () -> Void
    @State private var selectedReport: SkinReport?

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    if reports.isEmpty {
                        Text("No scan results yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        ForEach(reports.indices, id: \.self) { index in
                            SkinAnalysisHistoryCard(
                                report: reports[index],
                                onTap: {
                                    selectedReport = reports[index]
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 19)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: 16) {
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

                Text("Skin Analysis")
                    .font(.system(size: 30 * 0.6, weight: .medium))
                    .foregroundStyle(Color(hex: "161616"))

                Spacer()
            }
            .padding(.horizontal, 19)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(AppTheme.background)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedReport != nil },
                set: { if !$0 { selectedReport = nil } }
            )
        ) {
            ReportView(report: selectedReport ?? .placeholder, navigationStyle: .back, isLocked: false) {
                selectedReport = nil
            }
        }
    }

}

private struct SkinAnalysisHistoryCard: View {
    let report: SkinReport
    let onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        scoreBadge(score: report.overallScore)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(report.overallTitle)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(report.overallSubtitle)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(reportDate(report.createdAt))
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "BFBFBF"))
                        }
                    }

                    ForEach(orderedMetrics(from: report)) { metric in
                        AnalysisMetricRow(metric: metric)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }

    private func scoreBadge(score: Int) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFBF00"), Color(hex: "FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                .shadow(color: Color(hex: "FF8C00").opacity(0.45), radius: 4, y: 2)

            Text("\(score)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
    }

    private func reportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func orderedMetrics(from report: SkinReport) -> [AnalysisMetric] {
        let metricsByID = Dictionary(uniqueKeysWithValues: report.metrics.map { ($0.id, $0) })
        let placeholderByID = Dictionary(uniqueKeysWithValues: SkinReport.placeholder.metrics.map { ($0.id, $0) })

        struct AnalysisMetricStyle {
            let title: String
            let id: String
            let fallbackID: String?
            let colorHex: String
        }

        let style: [AnalysisMetricStyle] = [
            .init(title: "Acne", id: "acne", fallbackID: nil, colorHex: "F64F4F"),
            .init(title: "Radiance", id: "radiance", fallbackID: nil, colorHex: "FFC803"),
            .init(title: "Texture", id: "texture", fallbackID: "melanin", colorHex: "0BAE79"),
            .init(title: "Pores", id: "pores", fallbackID: nil, colorHex: "039EFF"),
            .init(title: "Wrinkles", id: "wrinkles", fallbackID: nil, colorHex: "C179FF"),
            .init(title: "Hydration", id: "hydration", fallbackID: nil, colorHex: "F192E4")
        ]

        return style.compactMap { item in
            let metric = metricsByID[item.id]
                ?? item.fallbackID.flatMap { metricsByID[$0] }
                ?? placeholderByID[item.id]
                ?? item.fallbackID.flatMap { placeholderByID[$0] }

            guard let metric else { return nil }

            return AnalysisMetric(
                title: item.title,
                valueText: "\(metric.score) / 100",
                progress: CGFloat(max(0, min(100, metric.score))) / 100,
                color: Color(hex: item.colorHex)
            )
        }
    }
}

private struct AnalysisMetric: Identifiable {
    let id = UUID()
    let title: String
    let valueText: String
    let progress: CGFloat
    let color: Color
}

private struct AnalysisMetricRow: View {
    let metric: AnalysisMetric

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(metric.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(metric.valueText)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(metric.color)
                        .frame(width: proxy.size.width * metric.progress)
                }
            }
            .frame(height: 4)
        }
    }
}

private struct HomeViewAllPreviewHost: View {
    @State private var isHistoryPresented = false

    var body: some View {
        HomeView(
            mode: .filled,
            report: sampleReports.first,
            favoriteProducts: [],
            onViewAllAnalysis: {
                isHistoryPresented = true
            }
        )
        .fullScreenCover(isPresented: $isHistoryPresented) {
            SkinAnalysisHistoryView(reports: sampleReports) {
                isHistoryPresented = false
            }
        }
    }

    private var sampleReports: [SkinReport] {
        [
            SkinReport(
                createdAt: Date(),
                overallScore: 50,
                overallTitle: "Fair",
                overallSubtitle: "Your skin is needs more care",
                metrics: [
                    .init(id: "acne", title: "Acne", score: 65, colorHex: "F64F4F"),
                    .init(id: "radiance", title: "Radiance", score: 60, colorHex: "FFC803"),
                    .init(id: "texture", title: "Texture", score: 70, colorHex: "0BAE79"),
                    .init(id: "pores", title: "Pores", score: 65, colorHex: "039EFF"),
                    .init(id: "wrinkles", title: "Wrinkles", score: 75, colorHex: "C179FF"),
                    .init(id: "hydration", title: "Hydration", score: 85, colorHex: "F192E4")
                ],
                generalFields: SkinReport.placeholder.generalFields
            ),
            SkinReport(
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                overallScore: 25,
                overallTitle: "Fair",
                overallSubtitle: "Your skin is needs more care",
                metrics: [
                    .init(id: "acne", title: "Acne", score: 45, colorHex: "F64F4F"),
                    .init(id: "radiance", title: "Radiance", score: 64, colorHex: "FFC803"),
                    .init(id: "texture", title: "Texture", score: 50, colorHex: "0BAE79"),
                    .init(id: "pores", title: "Pores", score: 65, colorHex: "039EFF"),
                    .init(id: "wrinkles", title: "Wrinkles", score: 50, colorHex: "C179FF"),
                    .init(id: "hydration", title: "Hydration", score: 55, colorHex: "F192E4")
                ],
                generalFields: SkinReport.placeholder.generalFields
            )
        ]
    }
}

private struct HomeFavoritesPreviewHost: View {
    private var sampleFavorites: [ScannedProduct] {
        [
            makeFavorite(
                title: "Advanced Snail 96 Mucin Power Essence",
                brand: "COSRX",
                category: "Skincare",
                score: 86
            ),
            makeFavorite(
                title: "Lip Sleeping Mask",
                brand: "Laneige",
                category: "Lips",
                score: 82
            ),
            makeFavorite(
                title: "Volumizing Mascara",
                brand: "Maybelline",
                category: "Eyes",
                score: 74
            )
        ]
    }

    var body: some View {
        HomeView(
            mode: .filled,
            report: .placeholder,
            favoriteProducts: sampleFavorites
        )
    }

    private func makeFavorite(title: String, brand: String, category: String, score: Int) -> ScannedProduct {
        let imageData = UIImage(systemName: "photo")?.pngData() ?? Data()
        let analysis = ProductAnalysis(
            isFaceProduct: true,
            rejectionReason: nil,
            productName: title,
            brand: brand,
            category: category,
            suitability: .suitable,
            suitabilityScore: score,
            suitabilitySummary: "Looks suitable for your profile.",
            pros: ["Hydrates skin"],
            cons: ["Patch test advised"],
            howToUse: ["Apply on clean skin"],
            warnings: ["Avoid eye contact"],
            ingredients: [
                .init(name: "Glycerin", details: "Humectant support.", verdict: .safe)
            ]
        )

        return ScannedProduct(
            id: UUID(),
            createdAt: Date(),
            imageData: imageData,
            title: title,
            brand: brand,
            category: category,
            isFavorite: true,
            analysisState: .completed(analysis)
        )
    }
}

#Preview("Home Filled (Unlocked)") {
    HomeView(mode: .filled, report: .placeholder, favoriteProducts: [.previewCompleted])
}

#Preview("Home Favorites Horizontal") {
    HomeFavoritesPreviewHost()
}

#Preview("Home Empty") {
    HomeView(mode: .empty, report: nil, favoriteProducts: [])
}

#Preview("Home -> View All") {
    HomeViewAllPreviewHost()
}
