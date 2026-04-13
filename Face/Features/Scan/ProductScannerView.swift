import SwiftUI
import UIKit

struct ProductScannerView: View {
    let tabBarInset: CGFloat
    @Binding var history: [ScannedProduct]
    let onOpenProduct: (ScannedProduct) -> Void
    let onAnalyzeImage: (UIImage) -> Void
    let onToggleFavorite: (ScannedProduct) -> Void
    let onDeleteProduct: (ScannedProduct) -> Void

    @State private var activePicker: PickerRequest?
    @State private var cameraAlertMessage: String?

    private struct PickerRequest: Identifiable {
        let id = UUID()
        let sourceType: UIImagePickerController.SourceType
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                scannerHeader
                 

                scannerCard
                    .padding(.top, 22)

                if history.isEmpty {
                    Spacer()
                    emptyState.padding(.bottom,50)
                      
                    Spacer()
                } else {
                    historyHeader
                        .padding(.top, 24)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(history) { product in
                                scannerHistoryRow(product: product)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding(.horizontal, 19)
           
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(item: $activePicker) { request in
            CameraCaptureView(sourceType: request.sourceType) { image in
                onAnalyzeImage(image)
            }
            .ignoresSafeArea()
        }
        .alert(
            "Camera Access Needed",
            isPresented: Binding(
                get: { cameraAlertMessage != nil },
                set: { if !$0 { cameraAlertMessage = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                CameraPermissionHelper.openAppSettings()
            }
        } message: {
            Text(cameraAlertMessage ?? CameraPermissionHelper.deniedMessage)
        }
    }

    private var scannerHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Product Scanner")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Scan products to check compatibility")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scannerCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppTheme.mainGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color(hex: "67008F").opacity(0.45), radius: 10)

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 83, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 18)
                .padding(.trailing, 18)

            VStack(alignment: .leading, spacing: 0) {
                Text("Check Product\nCompatibility")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                Text("AI analyzes ingredients for you")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                HStack(spacing: 16) {
                    actionButton(title: "Camera", icon: "camera.fill", isPrimary: true) {
                        presentCamera()
                    }

                    actionButton(title: "Gallery", icon: "photo.on.rectangle.angled", isPrimary: false) {
                        activePicker = .init(sourceType: .photoLibrary)
                    }
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 215)
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

            Text("Take a product scan to get\npersonalized recommendations")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var historyHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: "039EFF"))

            Text("History")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButton(title: String, icon: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))

                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(isPrimary ? AppTheme.accent : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPrimary ? .white : Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: isPrimary ? 0 : 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private func scannerHistoryRow(product: ScannedProduct) -> some View {
        ScannerHistoryCard(
            product: product,
            onOpenProduct: onOpenProduct,
            onToggleFavorite: onToggleFavorite,
            onDeleteProduct: onDeleteProduct
        )
    }

    private func presentCamera() {
        CameraPermissionHelper.requestAccess { result in
            switch result {
            case .granted:
                activePicker = .init(sourceType: .camera)
            case .denied(let message):
                cameraAlertMessage = message
            }
        }
    }
}

#Preview("Product Scanner (Empty)") {
    ProductScannerView(
        tabBarInset: 98,
        history: .constant([]),
        onOpenProduct: { _ in },
        onAnalyzeImage: { _ in },
        onToggleFavorite: { _ in },
        onDeleteProduct: { _ in }
    )
}

#Preview("Product Scanner (History)") {
    ProductScannerView(
        tabBarInset: 98,
        history: .constant([.previewCompleted]),
        onOpenProduct: { _ in },
        onAnalyzeImage: { _ in },
        onToggleFavorite: { _ in },
        onDeleteProduct: { _ in }
    )
}

private struct ScannerHistoryCard: View {
    let product: ScannedProduct
    let onOpenProduct: (ScannedProduct) -> Void
    let onToggleFavorite: (ScannedProduct) -> Void
    let onDeleteProduct: (ScannedProduct) -> Void

    @State private var dragOffsetX: CGFloat = 0
    @State private var isDeleting = false

    private let maxSwipeReveal: CGFloat = 150
    private let deleteTriggerDistance: CGFloat = 80
    private let deleteFlightDistance: CGFloat = 260

    private var canOpen: Bool {
        product.canOpenDetails
    }

    private var canFavorite: Bool {
        canOpen
    }

    private var isPending: Bool {
        if case .analyzing = product.analysisState {
            return true
        }
        return false
    }

    var body: some View {
        ZStack(alignment: dragOffsetX >= 0 ? .leading : .trailing) {
            deleteBackground
            cardContent
                .offset(x: dragOffsetX)
                .contentShape(Rectangle())
                .gesture(swipeToDeleteGesture)
                .onTapGesture {
                    if canOpen {
                        onOpenProduct(product)
                    }
                }
        }
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            imageThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(product.brand)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)

                Text(product.category)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 20)
                    .background(
                        Capsule()
                            .fill(AppTheme.accent.opacity(0.25))
                    )

                Text(product.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "565656"))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                trailingStatus
                Button {
                    onToggleFavorite(product)
                } label: {
                    Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "F192E4"))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(!canFavorite)
                .opacity(canFavorite ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 94)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 2)
        )
        .opacity(canOpen || isPending ? 1 : 0.9)
    }

    private var swipeProgress: CGFloat {
        min(max(abs(dragOffsetX) / deleteTriggerDistance, 0), 1)
    }

    private var deletePanelWidth: CGFloat {
        min(max(abs(dragOffsetX), 0), maxSwipeReveal)
    }

    private var deleteBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color.white.opacity(0.15))
            .overlay(alignment: dragOffsetX >= 0 ? .leading : .trailing) {
                if abs(dragOffsetX) > 0, deletePanelWidth > 0 {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(hex: "F64F4F").opacity(0.84))
                        .frame(width: deletePanelWidth)
                        .overlay(alignment: dragOffsetX >= 0 ? .leading : .trailing) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .bold))
                                if deletePanelWidth > 86 {
                                    Text("Delete")
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .opacity(0.65 + (0.35 * swipeProgress))
                        }
                        .animation(.easeOut(duration: 0.12), value: deletePanelWidth)
                }
            }
    }

    @ViewBuilder
    private var imageThumbnail: some View {
        if let image = UIImage(data: product.imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .frame(width: 62, height: 62)
        }
    }

    @ViewBuilder
    private var trailingStatus: some View {
        switch product.analysisState {
        case .analyzing:
            ProgressView()
                .tint(AppTheme.accent)
                .frame(width: 24, height: 24)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "FF8503"))
                .frame(width: 24, height: 24)
        case .completed(let analysis):
            if analysis.isFaceProduct {
                Image(systemName: product.recommendationSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: product.recommendationColorHex))
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "F64F4F"))
                    .frame(width: 24, height: 24)
            }
        }
    }

    private var swipeToDeleteGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isDeleting else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let rawOffset = value.translation.width
                dragOffsetX = min(max(rawOffset, -maxSwipeReveal), maxSwipeReveal)
            }
            .onEnded { value in
                guard !isDeleting else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                        dragOffsetX = 0
                    }
                    return
                }

                let distance = max(
                    abs(value.translation.width),
                    abs(value.predictedEndTranslation.width),
                    abs(dragOffsetX)
                )

                guard distance >= deleteTriggerDistance else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                        dragOffsetX = 0
                    }
                    return
                }

                isDeleting = true
                let direction: CGFloat = value.translation.width >= 0 ? 1 : -1
                withAnimation(.easeOut(duration: 0.16)) {
                    dragOffsetX = direction * deleteFlightDistance
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    onDeleteProduct(product)
                }
            }
    }
}
