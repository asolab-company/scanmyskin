import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var storeKit: StoreKitManager

    private let onClose: (() -> Void)?

    private let features: [PaywallFeature] = [
        .init(
            iconAsset: "app_ic_facev",
            title: "Unlimited Skin Analysis",
            subtitle: "Get detailed AI-powered skin analysis anytime"
        ),
        .init(
            iconAsset: "app_ic_scanv",
            title: "Product Scanner",
            subtitle: "24/7 AI assistant for personalized skin advice"
        ),
        .init(
            iconAsset: "app_ic_chatv",
            title: "AI Coach Unlimited",
            subtitle: "Scan products to check skin compatibility"
        )
    ]

    @State private var errorText = ""
    @State private var isShowingErrorAlert = false

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color(hex: "DEDEDE")
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    header

                    Image("app_ic_coach")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .padding(.top, 14)

                    Text("Unlock Premium")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color(hex: "222222"))
                        .padding(.top, 24)

                    Text("Get full access to all skin analysis features")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(hex: "222222"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    Text("Premium Features")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "222222"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                        .padding(.horizontal, 19)

                    VStack(spacing: 8) {
                        ForEach(features) { feature in
                            PaywallInfoCard(
                                iconAsset: feature.iconAsset,
                                title: feature.title,
                                subtitle: feature.subtitle
                            )
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 19)

                    PaywallInfoCard(
                        iconAsset: "app_ic_crownviolet",
                        title: "Annual Access",
                        subtitle: annualSubtitle
                    )
                    .padding(.top, 36)
                    .padding(.horizontal, 19)

                    HStack(spacing: 7) {
                        Image("ic_shield")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                        Text("Cancel Anytime")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "A148D1"))
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 16)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomArea
        }
        .task {
            storeKit.clearPurchaseError()
            await storeKit.loadProducts()
        }
        .alert("Purchase Error", isPresented: $isShowingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    private var annualSubtitle: String {
        if storeKit.isLoadingProducts && storeKit.annualProduct == nil {
            return "Loading price..."
        }
        return storeKit.annualPriceText
    }

    private var canPurchase: Bool {
        storeKit.annualProduct != nil && !storeKit.isPurchasing
    }

    private var header: some View {
        HStack {
            if let onClose {
                Button(action: onClose) {
                    Image("app_ic_close")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            } else {
                Image("app_ic_close")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }

            Spacer()
        }
        .padding(.horizontal, 27)
    }

    private var bottomArea: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let didPurchase = await storeKit.purchaseAnnual()
                    if didPurchase {
                        onClose?()
                    } else if let message = storeKit.purchaseErrorMessage, !message.isEmpty {
                        errorText = message
                        isShowingErrorAlert = true
                    }
                }
            } label: {
                PrimaryGradientButton(
                    title: storeKit.isPurchasing ? "Processing..." : "Continue",
                    height: 60
                )
            }
            .buttonStyle(.plain)
            .disabled(!canPurchase)
            .opacity(canPurchase ? 1 : 0.6)
            .padding(.horizontal, 19)

            HStack(spacing: 0) {
                Button("Privacy Policy") {
                    openURL(AppData.Links.privacyPolicy)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button("Restore") {
                    Task {
                        await storeKit.restorePurchases()
                        if storeKit.isPremium {
                            onClose?()
                        } else if let message = storeKit.purchaseErrorMessage, !message.isEmpty {
                            errorText = message
                            isShowingErrorAlert = true
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button("Terms of Use") {
                    openURL(AppData.Links.termsOfUse)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(hex: "939393"))
            .padding(.horizontal, 30)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(hex: "DEDEDE"))
    }
}

private struct PaywallFeature: Identifiable {
    let id = UUID()
    let iconAsset: String
    let title: String
    let subtitle: String
}

private struct PaywallInfoCard: View {
    let iconAsset: String
    let title: String
    let subtitle: String

    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color.white.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.99), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 0)
            .overlay(
                HStack(spacing: 16) {
                    Image(iconAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "222222"))
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "939393"))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            )
            .frame(height: 70)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreKitManager())
}
