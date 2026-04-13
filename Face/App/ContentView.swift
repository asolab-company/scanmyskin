import SwiftUI
import UIKit

enum MainTab {
    case home
    case scan
    case coach
}

struct ContentView: View {
    @EnvironmentObject private var storeKitManager: StoreKitManager

    @State private var selectedTab: MainTab = .home
    @State private var isScanFlowPresented = false
    @State private var isPaywallPresented = false
    @State private var isSettingsPresented = false
    @State private var isAnalysisHistoryPresented = false
    @State private var selectedReport: SkinReport?
    @State private var selectedProduct: ScannedProduct?
    @State private var scannedProducts: [ScannedProduct] = ScannedProductStore.load()
    @State private var scanCameraAlertMessage: String?

    @AppStorage(AppData.StorageKeys.latestReportData) private var latestReportData = Data()
    @AppStorage(AppData.StorageKeys.userName) private var storedUserName = ""
    @AppStorage(AppData.StorageKeys.age) private var storedAge = 0
    @AppStorage(AppData.StorageKeys.skinType) private var storedSkinType = ""
    @AppStorage(AppData.StorageKeys.skinTone) private var storedSkinTone = ""
    @AppStorage(AppData.StorageKeys.skinUndertone) private var storedSkinUndertone = ""
    @AppStorage(AppData.StorageKeys.productScanUsageDay) private var productScanUsageDay = ""
    @AppStorage(AppData.StorageKeys.productScanUsageCount) private var productScanUsageCount = 0

    private let productAnalyzer = OpenAIProductAnalyzer()

    var body: some View {
        ZStack(alignment: .bottom) {
            switch selectedTab {
            case .home:
                HomeView(
                    mode: (latestReport == nil && favoriteProducts.isEmpty) ? .empty : .filled,
                    report: latestReport,
                    favoriteProducts: favoriteProducts,
                    onStartScan: {
                        if !canStartNewAnalysis {
                            isPaywallPresented = true
                            return
                        }
                        requestFaceScanCameraAccess()
                    },
                    onOpenSettings: {
                        isSettingsPresented = true
                    },
                    onViewAllAnalysis: {
                        isAnalysisHistoryPresented = true
                    },
                    onOpenLatestReport: {
                        selectedReport = latestReport ?? .placeholder
                    },
                    onOpenFavoriteProduct: { product in
                        if let latest = scannedProducts.first(where: { $0.id == product.id }) {
                            selectedProduct = latest
                        } else {
                            selectedProduct = product
                        }
                    },
                    onRemoveFavoriteProduct: { product in
                        setFavorite(false, for: product.id)
                    }
                )
            case .scan:
                ProductScannerView(
                    tabBarInset: 98,
                    history: $scannedProducts,
                    onOpenProduct: { product in
                        if let latest = scannedProducts.first(where: { $0.id == product.id }) {
                            selectedProduct = latest
                        } else {
                            selectedProduct = product
                        }
                    },
                    onAnalyzeImage: { image in
                        handleSelectedProductImage(image)
                    },
                    onToggleFavorite: { product in
                        toggleFavorite(for: product.id)
                    },
                    onDeleteProduct: { product in
                        deleteScannedProduct(product.id)
                    }
                )
            case .coach:
                AICoachView(tabBarInset: 98)
            }

            HomeBottomNavigation(selectedTab: tabSelectionBinding)
                .padding(.horizontal, 19)
                .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: scannedProducts) { _, newProducts in
            ScannedProductStore.save(newProducts)
        }
        .alert(
            "Camera Access Needed",
            isPresented: Binding(
                get: { scanCameraAlertMessage != nil },
                set: { if !$0 { scanCameraAlertMessage = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                CameraPermissionHelper.openAppSettings()
            }
        } message: {
            Text(scanCameraAlertMessage ?? CameraPermissionHelper.deniedMessage)
        }
        .fullScreenCover(isPresented: $isScanFlowPresented) {
            OnboardingView(
                onFinished: {
                    isScanFlowPresented = false
                    selectedTab = .home
                },
                initialPage: 3,
                initialName: storedUserName,
                initialBirthDate: initialBirthDateFromStoredAge,
                didConfirmGender: true,
                didConfirmAge: storedAge > 0,
                mode: .captureOnly
            )
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView {
                isPaywallPresented = false
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            SettingsView(
                onClose: {
                    isSettingsPresented = false
                }
            )
        }
        .fullScreenCover(isPresented: $isAnalysisHistoryPresented) {
            SkinAnalysisHistoryView(reports: analysisHistory) {
                isAnalysisHistoryPresented = false
            }
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
        .fullScreenCover(item: $selectedProduct) { product in
            ProductView(
                product: product,
                isLocked: !storeKitManager.isPremium,
                onUnlock: {
                    selectedProduct = nil
                    DispatchQueue.main.async {
                        isPaywallPresented = true
                    }
                },
                onBack: {
                    selectedProduct = nil
                },
                onToggleFavorite: { id in
                    toggleFavorite(for: id)
                }
            )
        }
    }

    private var favoriteProducts: [ScannedProduct] {
        scannedProducts
            .filter { $0.isFavorite && $0.canOpenDetails }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func toggleFavorite(for productID: UUID) {
        guard let current = scannedProducts.first(where: { $0.id == productID }) else { return }
        setFavorite(!current.isFavorite, for: productID)
    }

    private func setFavorite(_ isFavorite: Bool, for productID: UUID) {
        if isFavorite {
            guard let product = scannedProducts.first(where: { $0.id == productID }), product.canOpenDetails else {
                return
            }
        }
        updateScannedProduct(id: productID) { product in
            product.isFavorite = isFavorite
        }
    }

    private func deleteScannedProduct(_ productID: UUID) {
        scannedProducts.removeAll { $0.id == productID }
        if selectedProduct?.id == productID {
            selectedProduct = nil
        }
    }

    private func syncSelectedProductIfNeeded(with updatedProduct: ScannedProduct) {
        guard selectedProduct?.id == updatedProduct.id else { return }
        selectedProduct = updatedProduct
    }

    @MainActor
    private func updateScannedProduct(id: UUID, _ transform: (inout ScannedProduct) -> Void) {
        guard let index = scannedProducts.firstIndex(where: { $0.id == id }) else { return }
        transform(&scannedProducts[index])
        let updatedProduct = scannedProducts[index]
        syncSelectedProductIfNeeded(with: updatedProduct)
    }

    private var latestReport: SkinReport? {
        guard !latestReportData.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SkinReport.self, from: latestReportData)
    }

    private var analysisHistory: [SkinReport] {
        SkinReportStore.loadHistory()
    }

    private var canStartNewAnalysis: Bool {
        storeKitManager.isPremium || analysisHistory.isEmpty
    }

    private var canAnalyzeNewProductToday: Bool {
        if storeKitManager.isPremium {
            return true
        }
        if productScanUsageDay != currentDayKey {
            return true
        }
        return productScanUsageCount < 1
    }

    private var currentDayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func registerProductScanUsageIfNeeded() {
        guard !storeKitManager.isPremium else { return }
        let today = currentDayKey
        if productScanUsageDay != today {
            productScanUsageDay = today
            productScanUsageCount = 1
        } else {
            productScanUsageCount += 1
        }
    }

    private var initialBirthDateFromStoredAge: Date {
        guard storedAge > 0 else {
            return Calendar.current.date(byAdding: .year, value: -29, to: Date()) ?? Date()
        }
        return Calendar.current.date(byAdding: .year, value: -storedAge, to: Date()) ?? Date()
    }

    private var userProfileForProducts: ProductUserProfile {
        let resolvedSkinType = normalizedProfileValue(storedSkinType)
            ?? profileValueFromLatestReport(
                preferredIDs: ["skin_type", "type"],
                preferredLabels: ["Skin Type"]
            )
            ?? "unknown"

        let resolvedSkinTone = normalizedProfileValue(storedSkinTone)
            ?? profileValueFromLatestReport(
                preferredIDs: ["skin_tone", "tone"],
                preferredLabels: ["Skin Tone"]
            )
            ?? "unknown"

        let resolvedSkinUndertone = normalizedProfileValue(storedSkinUndertone)
            ?? profileValueFromLatestReport(
                preferredIDs: ["skin_undertone", "undertone"],
                preferredLabels: ["Skin Undertone"]
            )
            ?? "unknown"

        return ProductUserProfile(
            age: storedAge > 0 ? storedAge : nil,
            skinType: resolvedSkinType,
            skinTone: resolvedSkinTone,
            skinUndertone: resolvedSkinUndertone
        )
    }

    private func profileValueFromLatestReport(preferredIDs: [String], preferredLabels: [String]) -> String? {
        guard let latestReport else { return nil }

        let normalizedIDs = Set(preferredIDs.map { $0.lowercased() })
        let normalizedLabels = Set(preferredLabels.map { $0.lowercased() })

        if let byID = latestReport.generalFields.first(where: { normalizedIDs.contains($0.id.lowercased()) }),
           let normalized = normalizedProfileValue(byID.value) {
            return normalized
        }

        if let byLabel = latestReport.generalFields.first(where: { normalizedLabels.contains($0.label.lowercased()) }),
           let normalized = normalizedProfileValue(byLabel.value) {
            return normalized
        }

        return nil
    }

    private func normalizedProfileValue(_ raw: String) -> String? {
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

    private func requestFaceScanCameraAccess() {
        CameraPermissionHelper.requestAccess { result in
            switch result {
            case .granted:
                isScanFlowPresented = true
            case .denied(let message):
                scanCameraAlertMessage = message
            }
        }
    }

    private func handleSelectedProductImage(_ image: UIImage) {
        guard canAnalyzeNewProductToday else {
            isPaywallPresented = true
            return
        }
        registerProductScanUsageIfNeeded()

        let pending = ScannedProduct.pending(from: image)
        scannedProducts.insert(pending, at: 0)

        let profile = userProfileForProducts
        Task {
            await runProductAnalysis(for: pending.id, image: image, profile: profile)
        }
    }

    private func runProductAnalysis(for id: UUID, image: UIImage, profile: ProductUserProfile) async {
        do {
            let analysis = try await productAnalyzer.analyze(image: image, profile: profile)
            await MainActor.run {
                updateScannedProduct(id: id) { product in
                    product.title = analysis.productName
                    product.brand = analysis.brand
                    product.category = analysis.category
                    product.analysisState = .completed(analysis)
                }
            }
        } catch {
            await MainActor.run {
                updateScannedProduct(id: id) { product in
                    product.title = "Analysis Failed"
                    product.brand = "Try Again"
                    product.category = "Error"
                    product.analysisState = .failed(productAnalysisErrorMessage(for: error))
                }
            }
        }
    }

    private func productAnalysisErrorMessage(for error: Error) -> String {
        if let analyzerError = error as? OpenAIProductAnalyzerError {
            switch analyzerError {
            case .missingAPIKey:
                return "OpenAI API key is missing."
            case .invalidResponse:
                return "Unable to analyze this photo right now."
            case .invalidJSON, .emptyReply:
                return "Unexpected analysis response. Please try again."
            }
        }
        return "Analysis failed. Please try another photo."
    }

    private var tabSelectionBinding: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .coach && !storeKitManager.isPremium {
                    isPaywallPresented = true
                    return
                }
                selectedTab = newTab
            }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreKitManager())
}
