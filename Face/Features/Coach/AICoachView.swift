import SwiftUI
import PhotosUI
import UIKit

private enum CoachConnectionState {
    case connecting
    case online
    case offline

    var title: String {
        switch self {
        case .connecting:
            return "Connecting..."
        case .online:
            return "Online"
        case .offline:
            return "Offline"
        }
    }

    var color: Color {
        switch self {
        case .connecting:
            return Color(hex: "939393")
        case .online:
            return Color(hex: "0BAE79")
        case .offline:
            return Color(hex: "F64F4F")
        }
    }
}

struct AICoachView: View {
    @State private var text = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var messages: [AICoachMessage] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var attachedImageData: Data?
    @State private var isPhotoPickerPresented = false
    @State private var isSending = false
    @State private var hasLoaded = false
    @State private var connectionState: CoachConnectionState = .connecting

    private let service = OpenAICoachService()
    var tabBarInset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background
                .ignoresSafeArea()
            
            Color.init(hex: "f0f0f0")
                .frame(height: 70)
                .offset(y:40)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topHeader

                if messages.isEmpty {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        emptyState
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 188)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                chatRow(message)
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 188 + tabBarInset)
                }
            }

            bottomComposer
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .task {
            if !hasLoaded {
                hasLoaded = true
                messages = AICoachMessageStore.load()
            }
            await refreshConnectionStatus()
        }
        .onChange(of: messages) { _, newMessages in
            AICoachMessageStore.save(newMessages)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                await loadAttachment(from: item)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            handleKeyboard(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
    }

    private var topHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Coach")
                    .font(.system(size: 40 * 0.6, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button(action: clearChatHistory) {
                    Image("app_ic_delete")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "F64F4F"))
                }
                .buttonStyle(.plain)
                .disabled(messages.isEmpty && attachedImageData == nil && text.isEmpty)
                .opacity(messages.isEmpty && attachedImageData == nil && text.isEmpty ? 0.45 : 1)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(connectionState.color)
                    .frame(width: 8, height: 8)
                Text(connectionState.title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(connectionState.color)
            }
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                Capsule()
                    .fill(connectionState.color.opacity(0.2))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 19)
        .padding(.bottom, 10)
        .background(
            AppTheme.background
                .opacity(0.92)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image("app_ic_coach")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)

            Text("This chat is\ncurrently empty")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Feel free to start the conversation\nby asking your beauty coach any\nquestion you have — whether it’s\nabout face care, scalp & hair care,\nmakeup, grooming, or personal style.\nYour journey to looking and feeling\nyour best starts here!")
                .font(.system(size: 14))
                .foregroundStyle(Color.init(hex: "939393"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func chatRow(_ message: AICoachMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.direction == .incoming {
                coachAvatar
                bubble(message)
                Spacer(minLength: 18)
            } else {
                Spacer(minLength: 18)
                bubble(message)
                profileAvatar
            }
        }
    }

    private func bubble(_ message: AICoachMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = message.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(message.direction == .incoming ? AppTheme.textPrimary : .white)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 298, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(message.direction == .incoming ? Color.white.opacity(0.5) : Color(hex: "C179FF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(message.direction == .incoming ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1)
                )
                .shadow(color: .black.opacity(message.direction == .incoming ? 0.08 : 0), radius: 1)
        )
    }

    private var coachAvatar: some View {
        Image("app_ic_coach")
            .resizable()
            .scaledToFit()
            .frame(width: 58, height: 58)
    }

    private var profileAvatar: some View {
        Image("app_ic_profile")
            .resizable()
            .scaledToFit()
            .frame(width: 58, height: 58)
    }

    private var bottomComposer: some View {
        let isKeyboardVisible = keyboardHeight > 0
        let lift = max(tabBarInset - 20, keyboardHeight - 25)
        let hasAttachment = attachedImageData != nil
        let backgroundHeight: CGFloat = hasAttachment ? 108 : 60
        let backgroundBottomFill: CGFloat = isKeyboardVisible ? 0 : lift

        return ZStack(alignment: .bottom) {
            Color.init(hex: "#f0f0f0")
                .frame(height: backgroundHeight + backgroundBottomFill)
                .ignoresSafeArea(edges: isKeyboardVisible ? [] : .bottom)
                .offset(y: isKeyboardVisible ? 0 : lift)
                .shadow(color: .black.opacity(0.1), radius: 4, y: -4)

            VStack(spacing: hasAttachment ? 8 : 0) {
                if let attachedImageData, let image = UIImage(data: attachedImageData) {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text("Photo attached")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Button(action: removeAttachment) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: "939393"))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 19)
                }

                HStack(spacing: 10) {
                    Button(action: { isPhotoPickerPresented = true }) {
                        Circle()
                            .fill(Color(hex: "939393").opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color(hex: "939393"))
                            )
                    }
                    .buttonStyle(.plain)

                    TextField("Ask Anything About Beauty...", text: $text)
                        .font(.system(size: 28 * 0.5, weight: .regular))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(AppTheme.accent, lineWidth: 1)
                                )
                        )

                    Button(action: sendMessage) {
                        Circle()
                            .fill(AppTheme.mainGradient)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Group {
                                    if isSending {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Image("app_btn_send")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            )
                            .shadow(color: Color(hex: "964CC4").opacity(0.29), radius: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .opacity(canSend ? 1 : 0.5)
                }
                .padding(.horizontal, 19)
            }
            .padding(.bottom, 10)
        }
        .padding(.bottom, lift)
        .animation(.easeOut(duration: 0.25), value: lift)
        .animation(.easeOut(duration: 0.2), value: isKeyboardVisible)
        .animation(.easeOut(duration: 0.2), value: hasAttachment)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var canSend: Bool {
        guard !isSending else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImageData != nil
    }

    private func clearChatHistory() {
        text = ""
        attachedImageData = nil
        selectedPhotoItem = nil
        messages = []
        AICoachMessageStore.clear()
    }

    private func removeAttachment() {
        attachedImageData = nil
        selectedPhotoItem = nil
    }

    private func sendMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = attachedImageData

        guard !trimmed.isEmpty || imageData != nil else { return }

        let userMessage = AICoachMessage(
            direction: .outgoing,
            text: trimmed,
            imageData: imageData
        )

        messages.append(userMessage)
        text = ""
        attachedImageData = nil
        selectedPhotoItem = nil
        isSending = true

        let context = messages
        Task {
            do {
                let replyText = try await service.generateReply(history: context, latestUserMessage: userMessage)
                let assistantMessage = AICoachMessage(direction: .incoming, text: replyText)
                await MainActor.run {
                    connectionState = .online
                    messages.append(assistantMessage)
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    connectionState = .offline
                    messages.append(
                        AICoachMessage(
                            direction: .incoming,
                            text: "I’m temporarily offline. Please try again in a moment."
                        )
                    )
                    isSending = false
                }
            }
        }
    }

    private func refreshConnectionStatus() async {
        await MainActor.run {
            connectionState = .connecting
        }
        let isOnline = await service.checkConnection()
        await MainActor.run {
            connectionState = isOnline ? .online : .offline
        }
    }

    private func loadAttachment(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    attachedImageData = compressToJPEG(data: data)
                }
            }
        } catch {
            await MainActor.run {
                attachedImageData = nil
            }
        }
    }

    private func compressToJPEG(data: Data) -> Data {
        guard let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.72) else {
            return data
        }
        return compressed
    }

    private func handleKeyboard(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        let overlap = max(0, UIScreen.main.bounds.height - frame.minY)
        withAnimation(.easeOut(duration: 0.25)) {
            keyboardHeight = overlap
        }
    }
}

#Preview {
    AICoachView(tabBarInset: 98)
}
