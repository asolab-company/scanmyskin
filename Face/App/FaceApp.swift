import SwiftUI

@main
struct FaceApp: App {
    @AppStorage(AppData.StorageKeys.didCompleteOnboarding) private var didCompleteOnboarding = false
    @AppStorage(AppData.StorageKeys.hasPendingInitialReport) private var hasPendingInitialReport = false
    @State private var didFinishLoading = false
    @State private var didDismissLaunchPaywall = false
    @StateObject private var storeKitManager = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if !didFinishLoading {
                    LoadingScreenView {
                        withAnimation(.easeOut(duration: 0.2)) {
                            didFinishLoading = true
                        }
                    }
                } else if !didCompleteOnboarding {
                    OnboardingView {
                        withAnimation(.easeOut(duration: 0.2)) {
                            didCompleteOnboarding = true
                            didDismissLaunchPaywall = false
                        }
                    }
                } else if hasPendingInitialReport {
                    ReportView(
                        report: SkinReportStore.loadLatest(),
                        navigationStyle: .close,
                        isLocked: !storeKitManager.isPremium
                    ) {
                        hasPendingInitialReport = false
                        if !storeKitManager.isPremium {
                            didDismissLaunchPaywall = false
                        }
                    }
                } else if !storeKitManager.isPremium && !didDismissLaunchPaywall {
                    PaywallView {
                        didDismissLaunchPaywall = true
                        hasPendingInitialReport = false
                    }
                } else {
                    ContentView()
                        .onAppear {
                            if hasPendingInitialReport {
                                hasPendingInitialReport = false
                            }
                        }
                }
            }
            .preferredColorScheme(.light)
            .environmentObject(storeKitManager)
        }
    }
}
