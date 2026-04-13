import Foundation
import UIKit

struct AICoachMessage: Identifiable, Codable, Equatable {
    enum Direction: String, Codable {
        case incoming
        case outgoing
    }

    let id: UUID
    let direction: Direction
    let text: String
    let imageData: Data?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        direction: Direction,
        text: String,
        imageData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.direction = direction
        self.text = text
        self.imageData = imageData
        self.createdAt = createdAt
    }
}

enum AICoachMessageStore {
    static func load() -> [AICoachMessage] {
        guard let data = UserDefaults.standard.data(forKey: AppData.StorageKeys.aiCoachMessagesData) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([AICoachMessage].self, from: data)) ?? []
    }

    static func save(_ messages: [AICoachMessage]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: AppData.StorageKeys.aiCoachMessagesData)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: AppData.StorageKeys.aiCoachMessagesData)
    }
}

enum OpenAICoachError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OPENAI_API_KEY is missing."
        case .invalidResponse:
            return "AI Coach is temporarily unavailable."
        case .emptyReply:
            return "AI Coach returned an empty response."
        }
    }
}

struct OpenAICoachService {
    func checkConnection() async -> Bool {
        guard !AppData.OpenAI.apiKey.isEmpty else { return false }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("Bearer \(AppData.OpenAI.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    func generateReply(history: [AICoachMessage], latestUserMessage: AICoachMessage) async throws -> String {
        guard !AppData.OpenAI.apiKey.isEmpty else {
            throw OpenAICoachError.missingAPIKey
        }

        var messages: [CoachChatCompletionsRequest.Message] = [
            .init(role: "system", content: .text(systemPrompt))
        ]

        for message in history.suffix(12) where message.id != latestUserMessage.id {
            switch message.direction {
            case .incoming:
                guard !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                messages.append(.init(role: "assistant", content: .text(message.text)))
            case .outgoing:
                let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasImage = message.imageData != nil
                if trimmed.isEmpty, hasImage {
                    messages.append(.init(role: "user", content: .text("User shared a face or head beauty image.")))
                } else if !trimmed.isEmpty {
                    messages.append(.init(role: "user", content: .text(trimmed)))
                }
            }
        }

        let latestText = latestUserMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let imageData = latestUserMessage.imageData {
            let base64 = imageData.base64EncodedString()
            messages.append(
                .init(
                    role: "user",
                    content: .multi([
                        .text(latestText.isEmpty ? "Please analyze this face/head beauty photo and give practical care advice." : latestText),
                        .image("data:image/jpeg;base64,\(base64)")
                    ])
                )
            )
        } else {
            messages.append(.init(role: "user", content: .text(latestText)))
        }

        let payload = CoachChatCompletionsRequest(
            model: AppData.OpenAI.model,
            messages: messages,
            temperature: 0.3
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppData.OpenAI.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAICoachError.invalidResponse
        }

        let completion = try JSONDecoder().decode(CoachChatCompletionsResponse.self, from: data)
        let content = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else {
            throw OpenAICoachError.emptyReply
        }
        return content
    }

    private var systemPrompt: String {
        """
        You are ScanMySkin AI Coach.
        You can ONLY answer questions about:
        - facial skin care and appearance
        - scalp and hair care
        - eyebrows, beard and moustache grooming
        - makeup, styling and head-focused beauty routines
        - interpreting face/head photos in a non-medical, cosmetic context

        Greetings and short social phrases like "hello", "hi", "thanks" are allowed.
        For greetings, respond warmly and ask how you can help with face/hair/scalp beauty.

        If user asks anything outside this scope, reply exactly:
        "I can only help with face, scalp, hair, grooming, and beauty-related questions."

        Style:
        - concise, practical, friendly
        - no diagnosis, no emergency instructions
        - if uncertain, say it's a best-effort estimate from provided text/image
        - respond in English only, even if the user writes in another language
        """
    }
}

private struct CoachChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: MessageContent
    }

    enum MessageContent: Encodable {
        case text(String)
        case multi([Part])

        struct Part: Encodable {
            let type: String
            let text: String?
            let imageURL: ImageURL?

            struct ImageURL: Encodable {
                let url: String
            }

            static func text(_ value: String) -> Part {
                Part(type: "text", text: value, imageURL: nil)
            }

            static func image(_ value: String) -> Part {
                Part(type: "image_url", text: nil, imageURL: ImageURL(url: value))
            }

            enum CodingKeys: String, CodingKey {
                case type
                case text
                case imageURL = "image_url"
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let value):
                try container.encode(value)
            case .multi(let parts):
                try container.encode(parts)
            }
        }
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct CoachChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }

    let choices: [Choice]
}
