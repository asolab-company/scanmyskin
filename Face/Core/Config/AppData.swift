import Foundation

enum AppData {
    enum Links {
        static let termsOfUse = URL(string: "https://docs.google.com/document/d/e/2PACX-1vTJuvBsdhVvcwxxPoPI7gv6528nz4U3yVaGmKjDhNsS8U-oFR_zIguWDdyRRFQB6i8qQRAglbkH9-RM/pub")!
        static let privacyPolicy = URL(string: "https://docs.google.com/document/d/e/2PACX-1vTJuvBsdhVvcwxxPoPI7gv6528nz4U3yVaGmKjDhNsS8U-oFR_zIguWDdyRRFQB6i8qQRAglbkH9-RM/pub")!
    }

    enum AppStore {
        static let appID = "6762124050"

        static var appURL: URL {
            URL(string: "https://apps.apple.com/app/id6762124050")!
        }

        static var reviewURL: URL {
            URL(string: "https://apps.apple.com/app/id6762124050?action=write-review")!
        }
    }

    enum Share {
        static let message = "Check out ScanMySkin app."
        static var appURL: URL { AppStore.appURL }
    }

    enum StorageKeys {
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let userName = "profile.userName"
        static let gender = "profile.gender"
        static let age = "profile.age"
        static let skinTone = "profile.skinTone"
        static let skinUndertone = "profile.skinUndertone"
        static let skinType = "profile.skinType"
        static let latestReportData = "report.latestData"
        static let reportHistoryData = "report.historyData"
        static let hasPendingInitialReport = "report.hasPendingInitialReport"
        static let isPremium = "subscription.isPremium"
        static let aiCoachMessagesData = "coach.messagesData"
        static let scannedProductsData = "products.scannedData"
        static let productScanUsageDay = "products.scanUsageDay"
        static let productScanUsageCount = "products.scanUsageCount"
        static let openAICachedAPIKey = "openai.cachedAPIKey"
    }

    enum StoreKit {
        static let annualProductID = "com.face.premium.annual"
        static let localConfigurationFileName = "TestSub"
    }

    enum OpenAI {
        static let model = "gpt-4o-mini"

        static var apiKey: String {
            if let cached = UserDefaults.standard.string(forKey: StorageKeys.openAICachedAPIKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !cached.isEmpty {
                return cached
            }
            let fromPlist = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
            let fromEnv = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            return [fromPlist, fromEnv].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? ""
        }
    }
}
