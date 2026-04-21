import SwiftUI
import UIKit
import AVFoundation
import Vision

enum OnboardingFlowMode {
    case full
    case captureOnly
}

struct OnboardingView: View {
    let onFinished: () -> Void
    @State private var page = 0
    @State private var userName = ""
    @State private var selectedGender: GenderOption = .female
    @State private var selectedCapturePosition: CapturePosition = .front
    @State private var capturedImages: [CapturePosition: UIImage] = [:]
    @State private var activeCapturePicker: CapturePickerRequest?
    @State private var isAnalyzing = false
    @State private var analysisErrorMessage: String?
    @State private var selectedBirthDate = Calendar.current.date(byAdding: .year, value: -29, to: Date()) ?? Date()
    @State private var didConfirmGender = false
    @State private var didConfirmAge = false
    @State private var expandedPicker: ExpandedPicker?
    @FocusState private var isNameFieldFocused: Bool
    @AppStorage(AppData.StorageKeys.userName) private var storedUserName = ""
    @AppStorage(AppData.StorageKeys.gender) private var storedGender = ""
    @AppStorage(AppData.StorageKeys.age) private var storedAge = 0
    @AppStorage(AppData.StorageKeys.hasPendingInitialReport) private var hasPendingInitialReport = false
    private let mode: OnboardingFlowMode

    private struct CapturePickerRequest: Identifiable {
        let id = UUID()
        let sourceType: UIImagePickerController.SourceType
        let position: CapturePosition
    }

    private static let fullFlowPages: [OnboardingPage] = [
        .init(
            title: "Welcome to ScanMySkin",
            subtitle: "Your AI-powered beauty coach that\nanalyzes products and gives personalized\nskincare advice",
            imageAssetName: "app_bg_onbording_1",
            kind: .intro
        ),
        .init(
            title: "Product Scanner",
            subtitle: "Check if products suit your skin based on\ningredients, compatibility, and your\npersonal needs.",
            imageAssetName: "app_bg_onbording_2",
            kind: .intro
        ),
        .init(
            title: "Let's Begin\nYour Journey",
            subtitle: "The data will help you customize the application individually for you.",
            imageAssetName: nil,
            kind: .profileSetup
        ),
        .init(
            title: "Front View",
            subtitle: "Look straight at the camera",
            imageAssetName: nil,
            kind: .faceCapture
        )
    ]

    private var pages: [OnboardingPage] {
        switch mode {
        case .full:
            return Self.fullFlowPages
        case .captureOnly:
            return [.init(
                title: "Front View",
                subtitle: "Look straight at the camera",
                imageAssetName: nil,
                kind: .faceCapture
            )]
        }
    }

    init(
        onFinished: @escaping () -> Void,
        initialPage: Int = 0,
        initialName: String = "",
        initialBirthDate: Date = Calendar.current.date(byAdding: .year, value: -29, to: Date()) ?? Date(),
        didConfirmGender: Bool = false,
        didConfirmAge: Bool = false,
        mode: OnboardingFlowMode = .full
    ) {
        self.onFinished = onFinished
        self.mode = mode
        let maxPage = Self.fullFlowPages.count - 1
        let clampedPage = max(0, min(initialPage, maxPage))
        _page = State(initialValue: mode == .captureOnly ? 0 : clampedPage)
        _userName = State(initialValue: initialName)
        _selectedGender = State(initialValue: .female)
        _selectedCapturePosition = State(initialValue: .front)
        _selectedBirthDate = State(initialValue: initialBirthDate)
        _didConfirmGender = State(initialValue: didConfirmGender)
        _didConfirmAge = State(initialValue: didConfirmAge)
        _expandedPicker = State(initialValue: nil)
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if currentPage.kind == .profileSetup {
                    profileSetupStep
                } else if currentPage.kind == .faceCapture {
                    faceCaptureStep
                } else {
                    introStep
                }

                Spacer(minLength: 0)

                bottomControls
            }

            if isStandaloneCaptureFlow {
                captureOnlyHeader
            }
        }
        .simultaneousGesture(onboardingSwipeGesture)
        .sheet(item: $activeCapturePicker) { request in
            CameraCaptureView(sourceType: request.sourceType) { image in
                handleCapturedImage(image, for: request.position)
            }
            .ignoresSafeArea()
        }
        .alert(
            "Analysis Error",
            isPresented: Binding(
                get: { analysisErrorMessage != nil },
                set: { if !$0 { analysisErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(analysisErrorMessage ?? "Something went wrong.")
        }
    }

    private var introStep: some View {
        VStack(spacing: 0) {
            topIllustration

            Text(currentPage.title)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top)

            Text(currentPage.subtitle)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "222222"))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .padding(.horizontal)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    private var profileSetupStep: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 64)

       
                Image("app_ic_coach")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            

            Text(currentPage.title)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(hex: "222222"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Text(currentPage.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "222222"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
                .padding(.top, 10)

            nameField
                .padding(.top, 24)

            selectorsBlock
                .padding(.top, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var faceCaptureStep: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 64)

            Image("app_ic_coach")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)

            Text(faceCaptureTitle)
                .font(.system(size: 44 * 0.57, weight: .semibold))
                .foregroundStyle(Color(hex: "222222"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Text(faceCaptureSubtitle)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "222222"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
                .padding(.top, 10)

            captureCards
                .padding(.top, 26)

            tipCard
                .padding(.top, 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear {
            syncCapturePositionWithProgress()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 0) {
            if !isStandaloneCaptureFlow {
                pageIndicator
                    .padding(.bottom, 20)
            }

            continueButton(title: continueButtonTitle, isEnabled: isContinueEnabled)
                .opacity(isContinueEnabled ? 1 : 0.45)
                .padding(.horizontal, 19)

            bottomAuxiliary
                .padding(.top, 12)
                .frame(height: 56)
        }
    }

    private var topIllustration: some View {
        ZStack {
            if let imageAssetName = currentPage.imageAssetName {
                Image(imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color(hex: "C4A2D7"), Color(hex: "806297")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay {
                    Image("app_ic_coach")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120, idealHeight: 320, maxHeight: .infinity, alignment: .bottom)
        .clipped()
        .ignoresSafeArea(edges: .top)
    }

    private var pageIndicator: some View {
        HStack(spacing: 10) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(index == page ? AppTheme.accent : Color(hex: "9B9B9B"))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var captureCards: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let cardWidth = max((proxy.size.width - (spacing * 2)) / 3, 0)

            HStack(spacing: spacing) {
                ForEach(CapturePosition.allCases) { position in
                    let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                    VStack(spacing: 6) {
                        ZStack {
                            Color.white.opacity(0.65)

                            if let captured = capturedImages[position] {
                                Image(uiImage: captured)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: cardWidth, height: 185)
                                    .clipped()
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(position == selectedCapturePosition ? AppTheme.accent : Color(hex: "9B9B9B"))
                            }
                        }
                        .frame(width: cardWidth, height: 185)
                        .clipShape(cardShape)
                        .overlay {
                            cardShape
                                .strokeBorder(
                                    position == selectedCapturePosition ? AppTheme.accent.opacity(0.9) : Color(hex: "CFCFCF"),
                                    lineWidth: position == selectedCapturePosition ? 1.6 : 1
                                )
                        }

                        Text(position.title)
                            .font(.system(size: 14))
                            .foregroundStyle(position == selectedCapturePosition ? AppTheme.accent : Color(hex: "9B9B9B"))
                    }
                    .frame(width: cardWidth)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        presentPhotoLibrary(for: position)
                    }
                }
            }
        }
        .frame(height: 213)
    }

    private var tipCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color(hex: "34A3FF"))

            Text("Use good light and remove makeup for best results")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(hex: "34A3FF"))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 64)
        .background(
            Capsule()
                .fill(Color(hex: "039EFF").opacity(0.1))
        )
    }

    private var nameField: some View {
        HStack(spacing: 10) {
    
              

                Image("app_ic_profile")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            
            .frame(width: 56, height: 56)

            TextField("What Is Your Name?", text: $userName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent, lineWidth: 1.1)
                )
                .focused($isNameFieldFocused)
        }
    }

    private var selectorsBlock: some View {
        VStack(spacing: 0) {
            selectorRow(title: "Gender", value: genderDisplayValue, isActive: expandedPicker == .gender)
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFieldFocused = false
                    if !didConfirmGender {
                        selectedGender = .female
                    }
                    didConfirmGender = true
                    togglePicker(.gender)
                }

            if expandedPicker == .gender {
                Picker("", selection: $selectedGender) {
                    ForEach(GenderOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .tint(Color(hex: "222222"))
                .frame(height: 128)
                .clipped()
                .onChange(of: selectedGender) { _, _ in
                    didConfirmGender = true
                }
            }

            Divider()
                .overlay(Color(hex: "939393"))
                .padding(.top, 10)

            selectorRow(title: "Age", value: ageDisplayValue, isActive: expandedPicker == .age)
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFieldFocused = false
                    didConfirmAge = true
                    togglePicker(.age)
                }
                .padding(.top, 10)

            if expandedPicker == .age {
                DatePicker("", selection: $selectedBirthDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(Color(hex: "222222"))
                    .frame(height: 128)
                    .clipped()
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .onChange(of: selectedBirthDate) { _, _ in
                        didConfirmAge = true
                    }
            }

       
        }
    }

    private func selectorRow(title: String, value: String, isActive: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "222222"))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 36)
                .frame(width: 140)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.84))
                )
        }
    }

    private var bottomAuxiliary: some View {
        Group {
            if currentPage.kind == .faceCapture {
                if isStandaloneCaptureFlow {
                    Color.clear
                } else {
                    Button("Skip For Now") {
                        handleSkipForNow()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "2C2C2C"))
                    .disabled(isAnalyzing)
                    .opacity(isAnalyzing ? 0.45 : 1)
                }
            } else {
                Text(legalText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tint(AppTheme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 64)
                    .opacity(isLegalVisible ? 1 : 0)
                    .allowsHitTesting(isLegalVisible)
            }
        }
    }

    private func continueButton(title: String, isEnabled: Bool) -> some View {
        PrimaryGradientButton(title: title, icon: continueButtonIcon, height: 60)
            .onTapGesture {
                guard isEnabled else { return }
                handleContinue()
            }
    }

    private var onboardingSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else { return }

                if horizontal < 0 {
                    guard canMoveForwardFromCurrentPage, page < pages.count - 1 else { return }
                    if currentPage.kind == .profileSetup {
                        persistProfileData()
                    }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        page += 1
                        expandedPicker = nil
                        isNameFieldFocused = false
                    }
                } else if horizontal > 0, page > 0 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        page -= 1
                        expandedPicker = nil
                        isNameFieldFocused = false
                    }
                }
            }
    }

    private var currentPage: OnboardingPage {
        pages[page]
    }

    private var ageYears: Int {
        max(0, Calendar.current.dateComponents([.year], from: selectedBirthDate, to: Date()).year ?? 0)
    }

    private var genderDisplayValue: String {
        didConfirmGender ? selectedGender.title : "Unknown"
    }

    private var ageDisplayValue: String {
        didConfirmAge ? "\(ageYears) years" : "0 years"
    }

    private var isProfileSetupValid: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && didConfirmGender && didConfirmAge
    }

    private var canMoveForwardFromCurrentPage: Bool {
        if currentPage.kind == .profileSetup {
            return isProfileSetupValid
        }
        return true
    }

    private var isContinueEnabled: Bool {
        if currentPage.kind == .faceCapture {
            return !isAnalyzing
        }
        return canMoveForwardFromCurrentPage
    }

    private var continueButtonTitle: String {
        if currentPage.kind == .faceCapture {
            if isAnalyzing {
                return "Analyzing..."
            }
            return allCaptureStepsCompleted ? "Analyze" : "Take Photo"
        }
        return "Continue"
    }

    private var continueButtonIcon: String? {
        if currentPage.kind == .faceCapture {
            return allCaptureStepsCompleted ? "sparkles" : "camera.fill"
        }
        return nil
    }

    private var isLegalVisible: Bool {
        page == 0
    }

    private var isStandaloneCaptureFlow: Bool {
        mode == .captureOnly
    }

    private var captureOnlyHeader: some View {
        VStack {
            HStack(spacing: 16) {
                Button(action: onFinished) {
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
                .disabled(isAnalyzing)
                .opacity(isAnalyzing ? 0.45 : 1)

                Text("New analysis")
                    .font(.system(size: 30 * 0.6, weight: .medium))
                    .foregroundStyle(Color(hex: "161616"))

                Spacer()
            }
            .padding(.horizontal, 19)
        
            .background(AppTheme.background)

            Spacer()
        }
    }

    private var faceCaptureTitle: String {
        "\(selectedCapturePosition.title) View"
    }

    private var faceCaptureSubtitle: String {
        switch selectedCapturePosition {
        case .front:
            return "Look straight at the camera"
        case .left:
            return "Look left at the camera"
        case .right:
            return "Look right at the camera"
        }
    }

    private var allCaptureStepsCompleted: Bool {
        CapturePosition.allCases.allSatisfy { capturedImages[$0] != nil }
    }

    private func handleContinue() {
        if currentPage.kind == .faceCapture {
            guard !isAnalyzing else { return }
            if allCaptureStepsCompleted {
                startSkinAnalysis()
            } else {
                presentCamera(for: selectedCapturePosition)
            }
            return
        }

        if page < pages.count - 1 {
            guard canMoveForwardFromCurrentPage else { return }
            if currentPage.kind == .profileSetup {
                persistProfileData()
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                page += 1
                expandedPicker = nil
                isNameFieldFocused = false
            }
        } else {
            guard canMoveForwardFromCurrentPage else { return }
            onFinished()
        }
    }

    private func togglePicker(_ picker: ExpandedPicker) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedPicker == picker {
                expandedPicker = nil
            } else {
                expandedPicker = picker
            }
        }
    }

    private func persistProfileData() {
        storedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        storedGender = selectedGender.title
        storedAge = ageYears
    }

    private func handleSkipForNow() {
        hasPendingInitialReport = false
        onFinished()
    }

    private func handleCapturedImage(_ image: UIImage, for position: CapturePosition) {
        capturedImages[position] = image
        syncCapturePositionWithProgress()
    }

    private func presentCamera(for position: CapturePosition) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            analysisErrorMessage = "Camera is unavailable on this device. In Simulator, please use Photo Library selection."
            return
        }

        selectedCapturePosition = position

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            activeCapturePicker = .init(sourceType: .camera, position: position)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        activeCapturePicker = .init(sourceType: .camera, position: position)
                    } else {
                        analysisErrorMessage = "Camera access is required to take photos. Please enable Camera access in Settings."
                    }
                }
            }
        case .denied, .restricted:
            analysisErrorMessage = "Camera access is disabled. Open Settings and allow Camera access for this app."
        @unknown default:
            analysisErrorMessage = "Unable to access the camera."
        }
    }

    private func presentPhotoLibrary(for position: CapturePosition) {
        selectedCapturePosition = position
        activeCapturePicker = .init(sourceType: .photoLibrary, position: position)
    }

    private func syncCapturePositionWithProgress() {
        if let next = CapturePosition.allCases.first(where: { capturedImages[$0] == nil }) {
            selectedCapturePosition = next
        }
    }

    private func startSkinAnalysis() {
        guard
            let front = capturedImages[.front],
            let left = capturedImages[.left],
            let right = capturedImages[.right]
        else {
            return
        }

        isAnalyzing = true
        analysisErrorMessage = nil

        Task {
            if !validateFaceSet(front: front, left: left, right: right) {
                await MainActor.run {
                    analysisErrorMessage = "No face detected. Please choose clear face photos for Front, Left, and Right."
                    isAnalyzing = false
                }
                return
            }

            do {
                let report = try await OpenAISkinAnalyzer().analyze(front: front, left: left, right: right)
                try SkinReportStore.save(report)
                await MainActor.run {
                    hasPendingInitialReport = true
                    onFinished()
                }
            } catch {
                await MainActor.run {
                    analysisErrorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isAnalyzing = false
            }
        }
    }

    private func validateFaceSet(front: UIImage, left: UIImage, right: UIImage) -> Bool {
        hasFace(in: front) && hasFace(in: left) && hasFace(in: right)
    }

    private func hasFace(in image: UIImage) -> Bool {
        guard let cgImage = normalizedCGImage(from: image) else { return false }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let count = request.results?.count ?? 0
            return count > 0
        } catch {
            return false
        }
    }

    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }

    private var legalText: AttributedString {
        var text = AttributedString("By Proceeding You Accept\nOur ")

        var terms = AttributedString("Terms Of Use")
        terms.link = AppData.Links.termsOfUse

        let middle = AttributedString(" And ")

        var privacy = AttributedString("Privacy Policy")
        privacy.link = AppData.Links.privacyPolicy

        text.append(terms)
        text.append(middle)
        text.append(privacy)

        return text
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageAssetName: String?
    let kind: OnboardingPageKind
}

private enum OnboardingPageKind {
    case intro
    case profileSetup
    case faceCapture
}

private enum ExpandedPicker {
    case gender
    case age
}

private enum GenderOption: String, CaseIterable, Identifiable {
    case male
    case female
    case another

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .another:
            return "Another"
        }
    }
}

private enum CapturePosition: String, CaseIterable, Identifiable {
    case front
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front:
            return "Front"
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}

#Preview("Onboarding Flow") {
    OnboardingView(onFinished: {})
}

#Preview("Onboarding 1 - Welcome") {
    OnboardingView(onFinished: {}, initialPage: 0)
}

#Preview("Onboarding 2 - Product Scanner") {
    OnboardingView(onFinished: {}, initialPage: 1)
}

#Preview("Onboarding 3 - Profile Setup") {
    OnboardingView(onFinished: {}, initialPage: 2)
}

#Preview("Onboarding 4 - Front View") {
    OnboardingView(
        onFinished: {},
        initialPage: 3,
        initialName: "Margo",
        didConfirmGender: true,
        didConfirmAge: true
    )
}
