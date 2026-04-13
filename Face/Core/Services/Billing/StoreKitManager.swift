import Foundation
import Combine
import StoreKit
import OSLog

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var annualProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var purchaseErrorMessage: String?
    @Published private(set) var billingDebugEvents: [String] = []

    @Published private(set) var isPremium: Bool

    private var updatesTask: Task<Void, Never>?
    private var didLoadProductsSuccessfully = false
    private var trackedSubscriptionIDs: Set<String> = [AppData.StoreKit.annualProductID]
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Face",
        category: "StoreKit"
    )
    private static let logDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private enum BillingLogLevel {
        case debug
        case info
        case warning
        case error
    }

    init() {
        isPremium = UserDefaults.standard.bool(forKey: AppData.StorageKeys.isPremium)
        billingLog("init: persistedPremium=\(isPremium)")
        billingLog("init: bundleID=\(Bundle.main.bundleIdentifier ?? "nil")")
        billingLog("init: local storekit IDs=\(Self.localStoreKitProductIDs().joined(separator: ","))")
        let storeKitEnvironment = ProcessInfo.processInfo.environment
            .filter { key, _ in
                let lowered = key.lowercased()
                return lowered.contains("storekit") || lowered.contains("sandbox")
            }
        if storeKitEnvironment.isEmpty {
            billingLog("init: StoreKit environment vars not found")
        } else {
            let description = storeKitEnvironment
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: " | ")
            billingLog("init: StoreKit environment vars=\(description)")
        }
        updatesTask = observeTransactionUpdates()
        Task {
            await refreshEntitlements(reason: "init")
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
        billingLog("loadProducts started. requestedIDs=\(ids.joined(separator: ","))")

        do {
            let products = try await Product.products(for: ids)
            billingLog("loadProducts completed. storeProductsCount=\(products.count)")
            if products.isEmpty {
                billingLog("StoreKit returned 0 products. Check active scheme StoreKit config and product IDs.", level: .warning)
            } else {
                for product in products {
                    let subscriptionPeriodDescription: String
                    if let period = product.subscription?.subscriptionPeriod {
                        subscriptionPeriodDescription = "\(period.value) x \(String(describing: period.unit))"
                    } else {
                        subscriptionPeriodDescription = "none"
                    }
                    billingLog(
                        "product loaded: id=\(product.id) price=\(product.displayPrice) type=\(String(describing: product.type)) subscriptionPeriod=\(subscriptionPeriodDescription)"
                    )
                }
            }
            let resolvedProduct =
                products.first(where: { $0.id == AppData.StoreKit.annualProductID })
                ?? products.first(where: { $0.subscription?.subscriptionPeriod.unit == .year })
                ?? products.first

            if let resolvedProduct {
                annualProduct = resolvedProduct
                trackedSubscriptionIDs.insert(resolvedProduct.id)
                didLoadProductsSuccessfully = true
                purchaseErrorMessage = nil
                billingLog("selected product: id=\(resolvedProduct.id) price=\(resolvedProduct.displayPrice)")
            } else {
                if let cached = cachedBeforeLoad {
                    annualProduct = cached
                    billingLog("no products returned. keeping cached product id=\(cached.id)", level: .warning)
                    purchaseErrorMessage = nil
                } else {
                    annualProduct = nil
                    didLoadProductsSuccessfully = false
                    purchaseErrorMessage = "No product found. Check Scheme > Run > Options > StoreKit Configuration and select TestSub.storekit."
                    billingLog("no products returned and no cached product is available.", level: .error)
                }
            }
        } catch {
            if let cached = cachedBeforeLoad {
                annualProduct = cached
                billingLog("loadProducts failed with error=\(error.localizedDescription). keeping cached product id=\(cached.id)", level: .warning)
                purchaseErrorMessage = nil
            } else {
                annualProduct = nil
                didLoadProductsSuccessfully = false
                purchaseErrorMessage = "Failed to load products. Check StoreKit test configuration in your active scheme."
                billingLog("loadProducts failed and no cached product. error=\(error.localizedDescription)", level: .error)
            }
        }
    }

    func purchaseAnnual() async -> Bool {
        purchaseErrorMessage = nil
        billingLog("purchaseAnnual started. annualProductExists=\(self.annualProduct != nil)")

        if annualProduct == nil {
            await loadProducts()
        }

        guard let product = annualProduct else {
            purchaseErrorMessage = "No product found. Check StoreKit test configuration in your active scheme."
            billingLog("purchaseAnnual aborted: annualProduct is nil after loadProducts", level: .error)
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
                    billingLog("purchaseAnnual verified. productID=\(transaction.productID)")
                    await transaction.finish()
                    await refreshEntitlements(reason: "purchaseAnnual")
                    return isPremium
                case .unverified:
                    purchaseErrorMessage = "Purchase verification failed."
                    billingLog("purchaseAnnual unverified.", level: .error)
                    return false
                }
            case .pending:
                purchaseErrorMessage = "Purchase is pending approval."
                billingLog("purchaseAnnual pending approval.", level: .warning)
                return false
            case .userCancelled:
                billingLog("purchaseAnnual cancelled by user.")
                return false
            @unknown default:
                purchaseErrorMessage = "Unexpected purchase state."
                billingLog("purchaseAnnual unknown result state.", level: .error)
                return false
            }
        } catch {
            purchaseErrorMessage = "Purchase failed. Please try again."
            billingLog("purchaseAnnual error=\(error.localizedDescription)", level: .error)
            return false
        }
    }

    func restorePurchases() async {
        purchaseErrorMessage = nil
        billingLog("restorePurchases started")
        do {
            try await AppStore.sync()
            await refreshEntitlements(reason: "restorePurchases")
            if !isPremium {
                purchaseErrorMessage = "No active subscription found to restore."
                billingLog("restorePurchases completed but no active entitlement.", level: .warning)
            } else {
                billingLog("restorePurchases success. premium=true")
            }
        } catch {
            purchaseErrorMessage = "Restore failed. Please try again."
            billingLog("restorePurchases error=\(error.localizedDescription)", level: .error)
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
                    billingLog("transaction update verified: productID=\(transaction.productID)")
                    await transaction.finish()
                case .unverified(let transaction, let error):
                    billingLog(
                        "transaction update UNVERIFIED: productID=\(transaction.productID) error=\(error.localizedDescription)",
                        level: .warning
                    )
                }
                await refreshEntitlements(reason: "transactionUpdate")
            }
        }
    }

    private func refreshEntitlements(reason: String) async {
        var hasPremiumEntitlement = false
        billingLog("refreshEntitlements started. reason=\(reason) trackedIDs=\(trackedSubscriptionIDs.joined(separator: ","))")

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                let isTracked = trackedSubscriptionIDs.contains(transaction.productID)
                let isRevoked = transaction.revocationDate != nil
                let expirationText = transaction.expirationDate
                    .map { Self.logDateFormatter.string(from: $0) }
                    ?? "none"
                billingLog(
                    "entitlement verified: productID=\(transaction.productID) tracked=\(isTracked) revoked=\(isRevoked) expiration=\(expirationText)"
                )

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
            case .unverified(let transaction, let error):
                billingLog(
                    "entitlement UNVERIFIED: productID=\(transaction.productID) error=\(error.localizedDescription)",
                    level: .warning
                )
            }
        }

        billingLog("refreshEntitlements completed. hasPremiumEntitlement=\(hasPremiumEntitlement)")
        setPremium(hasPremiumEntitlement)
    }

    private func setPremium(_ value: Bool) {
        if isPremium != value {
            billingLog("premium status changed: \(isPremium) -> \(value)")
        } else {
            billingLog("premium status unchanged: \(value)", level: .debug)
        }
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

    private func billingLog(_ message: String, level: BillingLogLevel = .info) {
        let timestamp = Self.logDateFormatter.string(from: Date())
        let line = "[\(timestamp)] [Billing] \(message)"

        switch level {
        case .debug:
            logger.debug("\(line, privacy: .public)")
        case .info:
            logger.info("\(line, privacy: .public)")
        case .warning:
            logger.warning("\(line, privacy: .public)")
        case .error:
            logger.error("\(line, privacy: .public)")
        }

        billingDebugEvents.append(line)
        if billingDebugEvents.count > 200 {
            billingDebugEvents.removeFirst(billingDebugEvents.count - 200)
        }
    }
}
