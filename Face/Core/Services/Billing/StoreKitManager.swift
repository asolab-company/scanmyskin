import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var annualProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var purchaseErrorMessage: String?
    @Published private(set) var isPremium: Bool

    private var updatesTask: Task<Void, Never>?
    private var didLoadProductsSuccessfully = false
    private var trackedSubscriptionIDs: Set<String> = [AppData.StoreKit.annualProductID]

    init() {
        isPremium = UserDefaults.standard.bool(forKey: AppData.StorageKeys.isPremium)
        updatesTask = observeTransactionUpdates()
        Task {
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func prepareIfNeeded() async {
        guard !(didLoadProductsSuccessfully && annualProduct != nil) else { return }
        await loadProducts()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        let ids = requestedProductIDs()
        let cachedBeforeLoad = annualProduct

        do {
            let products = try await Product.products(for: ids)
            let resolvedProduct =
                products.first(where: { $0.id == AppData.StoreKit.annualProductID })
                ?? products.first(where: { $0.subscription?.subscriptionPeriod.unit == .year })
                ?? products.first

            if let resolvedProduct {
                annualProduct = resolvedProduct
                trackedSubscriptionIDs.insert(resolvedProduct.id)
                didLoadProductsSuccessfully = true
                purchaseErrorMessage = nil
            } else {
                if let cached = cachedBeforeLoad {
                    annualProduct = cached
                    purchaseErrorMessage = nil
                } else {
                    annualProduct = nil
                    didLoadProductsSuccessfully = false
                    purchaseErrorMessage = "No product found. Check Scheme > Run > Options > StoreKit Configuration and select TestSub.storekit."
                }
            }
        } catch {
            if let cached = cachedBeforeLoad {
                annualProduct = cached
                purchaseErrorMessage = nil
            } else {
                annualProduct = nil
                didLoadProductsSuccessfully = false
                purchaseErrorMessage = "Failed to load products. Check StoreKit test configuration in your active scheme."
            }
        }
    }

    func purchaseAnnual() async -> Bool {
        purchaseErrorMessage = nil

        if annualProduct == nil {
            await loadProducts()
        }

        guard let product = annualProduct else {
            purchaseErrorMessage = "No product found. Check StoreKit test configuration in your active scheme."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return isPremium
                case .unverified:
                    purchaseErrorMessage = "Purchase verification failed."
                    return false
                }
            case .pending:
                purchaseErrorMessage = "Purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                purchaseErrorMessage = "Unexpected purchase state."
                return false
            }
        } catch {
            purchaseErrorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    func restorePurchases() async {
        purchaseErrorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium {
                purchaseErrorMessage = "No active subscription found to restore."
            }
        } catch {
            purchaseErrorMessage = "Restore failed. Please try again."
        }
    }

    func clearPurchaseError() {
        purchaseErrorMessage = nil
    }

    var annualPriceText: String {
        guard let annualProduct else { return "$--.-- / Year" }
        return "\(annualProduct.displayPrice) / Year"
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction):
                    await transaction.finish()
                case .unverified:
                    break
                }
                await refreshEntitlements()
            }
        }
    }

    private func refreshEntitlements() async {
        var hasPremiumEntitlement = false

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                let isTracked = trackedSubscriptionIDs.contains(transaction.productID)
                let isRevoked = transaction.revocationDate != nil

                guard isTracked else { continue }
                guard !isRevoked else { continue }

                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        hasPremiumEntitlement = true
                        break
                    }
                } else {
                    hasPremiumEntitlement = true
                    break
                }
            case .unverified:
                break
            }
        }

        setPremium(hasPremiumEntitlement)
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: AppData.StorageKeys.isPremium)
    }

    private func requestedProductIDs() -> [String] {
        var ids = Set([AppData.StoreKit.annualProductID])
        ids.formUnion(Self.localStoreKitProductIDs())
        return Array(ids)
    }

    private static func localStoreKitProductIDs() -> [String] {
        let fileName = AppData.StoreKit.localConfigurationFileName
        var candidateURLs: [URL] = [
            Bundle.main.url(forResource: fileName, withExtension: "storekit"),
            Bundle.main.url(forResource: fileName, withExtension: "storekit", subdirectory: "StoreKit"),
            Bundle.main.url(forResource: fileName, withExtension: "storekit", subdirectory: "Resources/StoreKit")
        ]
        .compactMap { $0 }

        if let discovered = Bundle.main.urls(forResourcesWithExtension: "storekit", subdirectory: nil) {
            candidateURLs.append(contentsOf: discovered)
        }

        var uniqueURLs: [URL] = []
        var seenPaths: Set<String> = []
        for url in candidateURLs {
            if seenPaths.insert(url.path).inserted {
                uniqueURLs.append(url)
            }
        }

        var result: Set<String> = []
        for url in uniqueURLs {
            guard
                let data = try? Data(contentsOf: url),
                let object = try? JSONSerialization.jsonObject(with: data)
            else {
                continue
            }
            collectProductIDs(from: object, into: &result)
        }

        return Array(result)
    }

    private static func collectProductIDs(from object: Any, into result: inout Set<String>) {
        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                if key == "productID", let id = value as? String, !id.isEmpty {
                    result.insert(id)
                } else {
                    collectProductIDs(from: value, into: &result)
                }
            }
            return
        }

        if let array = object as? [Any] {
            for value in array {
                collectProductIDs(from: value, into: &result)
            }
        }
    }
}
