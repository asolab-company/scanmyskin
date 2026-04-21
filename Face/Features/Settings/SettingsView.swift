import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Environment(\.openURL) private var openURL
    var onClose: (() -> Void)? = nil
    var onOpenPremium: (() -> Void)? = nil
    @AppStorage(AppData.StorageKeys.userName) private var storedUserName = ""
    @AppStorage(AppData.StorageKeys.age) private var storedAge = 0
    @AppStorage(AppData.StorageKeys.skinTone) private var storedSkinTone = ""
    @AppStorage(AppData.StorageKeys.skinUndertone) private var storedSkinUndertone = ""
    @AppStorage(AppData.StorageKeys.skinType) private var storedSkinType = ""
    @AppStorage(AppData.StorageKeys.latestReportData) private var latestReportData = Data()
    @State private var isDeleteConfirmationPresented = false
    @State private var shareSheetPayload: ShareSheetPayload?
    @State private var isProfilePresented = false
    @State private var isPremiumPaywallPresented = false
    @State private var isCitationsPresented = false
    @State private var alertModel: SettingsAlertModel?

    private let supportRows: [SettingsRowModel] = [
        .init(icon: "book.closed", title: "Citations and Sources", action: .citations),
        .init(icon: "lock.shield", title: "Privacy", action: .privacy),
        .init(icon: "doc", title: "Terms and Conditions", action: .terms)
    ]

    private let generalRows: [SettingsRowModel] = [
        .init(icon: "square.and.arrow.up", title: "Share app", action: .share),
        .init(icon: "star.fill", title: "Rate Us", action: .rate),
        .init(icon: "arrow.counterclockwise", title: "Restore", action: .restore),
        .init(icon: "trash", title: "Delete Data", iconColor: Color(hex: "F64F4F"), action: .deleteData)
    ]

    private var visibleGeneralRows: [SettingsRowModel] {
        guard storeKitManager.isPremium else { return generalRows }
        return generalRows.filter { row in
            switch row.action {
            case .restore:
                return false
            default:
                return true
            }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    topHeader

                    if !storeKitManager.isPremium {
                        premiumButton
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 19)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader(
                            title: "Profile",
                            tint: Color.init(hex: "C179FF"),
                            icon: "app_ic_proff",
                            trailing: AnyView(
                                Button(action: { isProfilePresented = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Edit")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundStyle(AppTheme.accent)
                                }
                                .buttonStyle(.plain)
                            )
                        )
                        .padding(.top, 24)

                        profileCard
                            .padding(.top, 14)

                        sectionHeader(title: "Support & Legal", tint: Color(hex: "039EFF"), icon: "app_ic_info")
                            .padding(.top, 24)

                        VStack(spacing: 8) {
                            ForEach(supportRows) { row in
                                settingsRow(row)
                            }
                        }
                        .padding(.top, 12)

                        sectionHeader(title: "General", tint: Color(hex: "0BAE79"), icon: "app_ic_sett")
                            .padding(.top, 24)

                        VStack(spacing: 8) {
                            ForEach(visibleGeneralRows) { row in
                                settingsRow(row)
                            }
                        }
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 19)
                    .padding(.bottom, 24)
                }
            }

        }
        .sheet(item: $shareSheetPayload) { payload in
            ActivityViewController(activityItems: payload.items)
                .presentationDetents([.medium])
        }
        .alert("Delete Data", isPresented: $isDeleteConfirmationPresented) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) {
                deleteAllLocalData()
            }
        } message: {
            Text("Are you sure you want to delete all your local data and scan history?")
        }
        .fullScreenCover(isPresented: $isProfilePresented) {
            ProfileView {
                isProfilePresented = false
            }
        }
        .fullScreenCover(isPresented: $isPremiumPaywallPresented) {
            PaywallView {
                isPremiumPaywallPresented = false
            }
        }
        .fullScreenCover(isPresented: $isCitationsPresented) {
            CitationsAndSourcesView {
                isCitationsPresented = false
            }
        }
        .alert(item: $alertModel) { model in
            Alert(
                title: Text(model.title),
                message: Text(model.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var topHeader: some View {
        HStack(spacing: 16) {
            Button {
                onClose?()
            } label: {
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

            Text("Settings")
                .font(.system(size: 30 * 0.6, weight: .medium))
                .foregroundStyle(Color(hex: "161616"))

            Spacer()
        }
    }

    private var premiumButton: some View {
        Button {
            if let onOpenPremium {
                onOpenPremium()
            } else {
                isPremiumPaywallPresented = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Go To PREMIUM")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppTheme.mainGradient)
                    .shadow(color: Color(hex: "67008F").opacity(0.55), radius: 10)
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(title: String, tint: Color, icon: String, trailing: AnyView = AnyView(EmptyView())) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(tint)
                .frame(width: 2, height: 24)

            Image(icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            trailing
        }
    }

    private var profileCard: some View {
        VStack(spacing: 8) {
            profileField(label: "Name", value: profileName)
            profileField(label: "Age", value: profileAge)
            profileField(label: "Skin Tone", value: profileSkinTone)
            profileField(label: "Skin Undertone", value: profileSkinUndertone)
            profileField(label: "Skin Type", value: profileSkinType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
    }

    private func profileField(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func settingsRow(_ row: SettingsRowModel) -> some View {
        Button(action: { handleRowAction(row.action) }) {
            HStack(spacing: 16) {
                Image(systemName: row.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(row.iconColor)
                    .frame(width: 34, height: 34)

                Text(row.title)
                    .font(.system(size: 32 * 0.5, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "939393"))
            }
            .padding(.horizontal, 16)
            .frame(height: 66)
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
        .buttonStyle(.plain)
    }

    private func handleRowAction(_ action: SettingsRowAction) {
        switch action {
        case .citations:
            isCitationsPresented = true
        case .privacy:
            openURL(AppData.Links.privacyPolicy)
        case .terms:
            openURL(AppData.Links.termsOfUse)
        case .share:
            let shareText = "\(AppData.Share.message)\n\(AppData.Share.appURL.absoluteString)"
            shareSheetPayload = .init(items: [shareText, AppData.Share.appURL])
        case .rate:
            openURL(AppData.AppStore.reviewURL)
        case .restore:
            Task {
                await storeKitManager.restorePurchases()
                await MainActor.run {
                    if storeKitManager.isPremium {
                        alertModel = .init(title: "Success", message: "Your subscription has been restored.")
                    } else {
                        alertModel = .init(
                            title: "Restore",
                            message: storeKitManager.purchaseErrorMessage ?? "No active subscription found to restore."
                        )
                    }
                }
            }
        case .deleteData:
            isDeleteConfirmationPresented = true
        }
    }

    private func deleteAllLocalData() {
        let defaults = UserDefaults.standard
        let keysToRemove = [
            AppData.StorageKeys.didCompleteOnboarding,
            AppData.StorageKeys.userName,
            AppData.StorageKeys.gender,
            AppData.StorageKeys.age,
            AppData.StorageKeys.skinTone,
            AppData.StorageKeys.skinUndertone,
            AppData.StorageKeys.skinType,
            AppData.StorageKeys.latestReportData,
            AppData.StorageKeys.reportHistoryData,
            AppData.StorageKeys.hasPendingInitialReport,
            AppData.StorageKeys.didAcceptFaceAnalysisConsent,
            AppData.StorageKeys.isPremium,
            AppData.StorageKeys.aiCoachMessagesData,
            AppData.StorageKeys.scannedProductsData,
            AppData.StorageKeys.productScanUsageDay,
            AppData.StorageKeys.productScanUsageCount
        ]

        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()
        alertModel = .init(title: "Done", message: "All local data has been deleted.")
    }

    private var latestReport: SkinReport? {
        guard !latestReportData.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SkinReport.self, from: latestReportData)
    }

    private var profileName: String {
        let value = storedUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Not set yet" : value
    }

    private var profileAge: String {
        storedAge > 0 ? "\(storedAge) years" : "Not set yet"
    }

    private var profileSkinTone: String {
        let profileValue = normalizedFieldValue(storedSkinTone)
        if let profileValue { return profileValue }
        return analysisGeneralValue(
            preferredIDs: ["skin_tone", "tone"],
            preferredLabels: ["Skin Tone"]
        ) ?? "Not set yet"
    }

    private var profileSkinUndertone: String {
        let profileValue = normalizedFieldValue(storedSkinUndertone)
        if let profileValue { return profileValue }
        return analysisGeneralValue(
            preferredIDs: ["skin_undertone", "undertone"],
            preferredLabels: ["Skin Undertone"]
        ) ?? "Not set yet"
    }

    private var profileSkinType: String {
        let profileValue = normalizedFieldValue(storedSkinType)
        if let profileValue { return profileValue }
        return analysisGeneralValue(
            preferredIDs: ["skin_type", "type"],
            preferredLabels: ["Skin Type"]
        ) ?? "Not set yet"
    }

    private func analysisGeneralValue(preferredIDs: [String], preferredLabels: [String]) -> String? {
        guard let latestReport else { return nil }

        let normalizedIDs = Set(preferredIDs.map { $0.lowercased() })
        let normalizedLabels = Set(preferredLabels.map { $0.lowercased() })

        if let byID = latestReport.generalFields.first(where: { normalizedIDs.contains($0.id.lowercased()) }),
           let normalized = normalizedFieldValue(byID.value) {
            return normalized
        }

        if let byLabel = latestReport.generalFields.first(where: { normalizedLabels.contains($0.label.lowercased()) }),
           let normalized = normalizedFieldValue(byLabel.value) {
            return normalized
        }

        return nil
    }

    private func normalizedFieldValue(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let lowered = value.lowercased()
        let unavailableValues: Set<String> = [
            "unknown",
            "not set",
            "not set yet",
            "n/a",
            "-"
        ]

        if unavailableValues.contains(lowered) {
            return nil
        }

        return value
    }
}

private struct SettingsRowModel: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let iconColor: Color
    let action: SettingsRowAction

    init(icon: String, title: String, iconColor: Color = Color(hex: "939393"), action: SettingsRowAction) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.action = action
    }
}

private enum SettingsRowAction {
    case citations
    case privacy
    case terms
    case share
    case rate
    case restore
    case deleteData
}

private struct SettingsAlertModel: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ShareSheetPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CitationsAndSourcesView: View {
    @Environment(\.openURL) private var openURL
    let onClose: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 19)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The ScanMySkin utilizes cutting-edge artificial intelligence to evaluate images of skin lesions and moles. It is trained on an extensive database of dermatological research, clinical guidelines, and trusted medical literature from sources including:")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textPrimary)

                        sourcesBlock

                        Text("By continuously integrating the latest clinical research, the AI system enhances its ability to identify both common and potentially serious skin conditions. While the app does not offer a medical diagnosis, it provides risk assessments based on established dermatological standards.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Each image submitted is analyzed through AI-driven pattern recognition, matching visual features against comprehensive medical reference data. Users receive a preliminary risk assessment along with educational insights, helping them make informed decisions about seeking professional medical advice.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .stroke(Color.white.opacity(0.95), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 2)
                    )
                    .padding(.horizontal, 19)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button(action: onClose) {
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

            Text("Citations and Sources")
                .font(.system(size: 30 * 0.56, weight: .medium))
                .foregroundStyle(Color(hex: "161616"))

            Spacer(minLength: 0)
        }
    }

    private var sourcesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sourceRow(
                title: "American Academy of Dermatology (AAD)",
                urlString: "https://www.aad.org"
            )
            sourceRow(
                title: "Skin Cancer Foundation",
                urlString: "https://www.skincancer.org"
            )
            sourceRow(
                title: "National Rosacea Society",
                urlString: "https://www.rosacea.org"
            )
            sourceRow(
                title: "National Center for Biotechnology Information (NCBI)",
                urlString: "https://www.ncbi.nlm.nih.gov"
            )
        }
        .padding(.leading, 4)
    }

    private func sourceRow(title: String, urlString: String) -> some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            openURL(url)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(urlString)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "039EFF"))
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreKitManager())
}
