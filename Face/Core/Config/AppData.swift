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
    }

    enum StoreKit {
        static let annualProductID = "com.face.premium.annual"
        static let localConfigurationFileName = "TestSub"
    }

    enum OpenAI {
        static let model = "gpt-4o-mini"
        private static let embeddedAPIKey = "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"

        static var apiKey: String {
            (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String)
                ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
                ?? embeddedAPIKey
        }
    }
}
