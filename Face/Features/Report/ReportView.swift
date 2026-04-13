import SwiftUI

enum ReportNavigationStyle {
    case close
    case back
}

struct ReportView: View {
    private let onClose: (() -> Void)?
    private let navigationStyle: ReportNavigationStyle
    private let isReportLocked: Bool
    @State private var report: SkinReport

    private let horizontalPadding: CGFloat = 19

    init(
        report: SkinReport? = nil,
        navigationStyle: ReportNavigationStyle = .close,
        isLocked: Bool? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.onClose = onClose
        self.navigationStyle = navigationStyle
        self.isReportLocked = isLocked ?? (navigationStyle == .close)
        _report = State(initialValue: report ?? SkinReportStore.loadLatest() ?? .placeholder)
    }

    var body: some View {
        ZStack {
            Color(hex: "DEDEDE")
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
              

                    overallCard

                    generalHeader

                    generalCard
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, shouldShowUnlockButton ? 116 : 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if shouldShowUnlockButton {
                unlockButton
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
            }
        }
    }

    private var header: some View {
        HStack {
            if let onClose {
                Button(action: onClose) {
                    leadingControl
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()

            Text("Your Report")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: "161616"))

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
    }

    @ViewBuilder
    private var leadingControl: some View {
        switch navigationStyle {
        case .close:
            Image("report_ic_close")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
        case .back:
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
    }

    private var overallCard: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color.white.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.99), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0)
            .overlay(
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        scoreBadge

                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.overallTitle)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color(hex: "222222"))

                            Text(report.overallSubtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "939393"))

                            Text(dateLabel)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color(hex: "BFBFBF"))
                        }
                    }
                    .padding(.bottom, 12)

                    ForEach(reportMetricsForCard) { metric in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(metric.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(hex: "222222"))

                                Spacer()

                                Text("\(metric.score) / 100")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color(hex: "939393"))
                            }

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white)
                                    Capsule()
                                        .fill(Color(hex: metric.colorHex))
                                        .shadow(color: Color(hex: metric.colorHex).opacity(0.5), radius: 2, x: 0, y: 1)
                                        .frame(width: proxy.size.width * metricFillRatio(for: metric))
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.bottom, 9)
                    }    .blur(radius: isReportLocked ? 5 : 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(isReportLocked ? 0.15 : 0))
            )
            .frame(height: 262)
    }

    private var scoreBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFBF00"), Color(hex: "FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .trim(from: 0.06, to: 0.94)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                )
                .shadow(color: Color(hex: "FF8C00").opacity(0.33), radius: 4, x: 0, y: 4)

            Text("\(report.overallScore)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
    }

    private var generalHeader: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(hex: "C179FF"))
                .frame(width: 2, height: 24)

            Image("report_ic_doc")
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 21)

            Text("General Report")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "222222"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var generalCard: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color.white.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.99), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0)
            .overlay(
                VStack(spacing: 7) {
                    ForEach(report.generalFields) { field in
                        HStack {
                            Text("\(field.label):")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "939393"))

                            Spacer()

                            if let status = field.status, status != .neutral {
                                let colors = statusColors(for: status)
                                Text(field.value)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(colors.text)
                                    .frame(width: status == .present ? 71 : 92, height: 20)
                                    .background(
                                        Capsule()
                                            .fill(colors.background)
                                    )
                                    .blur(radius: isReportLocked ? 5 : 0)
                            } else {
                                Text(field.value)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "222222"))
                                    .blur(radius: isReportLocked ? 5 : 0)
                            }
                            
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
             
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(isReportLocked ? 0.15 : 0))
            )
            .frame(height: 241)
    }

    private var unlockButton: some View {
        Button {
            onClose?()
        } label: {
            Text("Unlock Full Report")
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

    private var shouldShowUnlockButton: Bool {
        isReportLocked && navigationStyle == .close
    }

    private func statusColors(for status: SkinReport.GeneralField.Status) -> (text: Color, background: Color) {
        switch status {
        case .present:
            return (Color(hex: "0BAE79"), Color(hex: "0BAE79").opacity(0.30))
        case .notPresent:
            return (Color(hex: "F64F4F"), Color(hex: "F64F4F").opacity(0.30))
        case .neutral:
            return (Color(hex: "222222"), .clear)
        }
    }

    private func metricFillRatio(for metric: SkinReport.Metric) -> CGFloat {
        CGFloat(max(0, min(100, metric.score))) / 100
    }

    private var reportMetricsForCard: [SkinReport.Metric] {
        let orderedIDs = ["acne", "pores", "wrinkles", "melanin"]
        let byID = Dictionary(uniqueKeysWithValues: report.metrics.map { ($0.id, $0) })
        let selected = orderedIDs.compactMap { byID[$0] }
        if selected.count == orderedIDs.count {
            return selected
        }
        return Array(report.metrics.prefix(4))
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: report.createdAt)
    }
}

#Preview {
    ReportView()
}
