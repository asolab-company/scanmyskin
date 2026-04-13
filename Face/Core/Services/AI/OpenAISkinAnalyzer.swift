import Foundation
import UIKit

enum OpenAISkinAnalyzerError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OPENAI_API_KEY is missing. Add it to Info.plist."
        case .invalidResponse:
            return "OpenAI response is invalid."
        case .invalidJSON:
            return "OpenAI returned non-JSON data."
        }
    }
}

struct OpenAISkinAnalyzer {
    func analyze(front: UIImage, left: UIImage, right: UIImage) async throws -> SkinReport {
        guard !AppData.OpenAI.apiKey.isEmpty else {
            throw OpenAISkinAnalyzerError.missingAPIKey
        }

        let frontBase64 = try encode(image: front)
        let leftBase64 = try encode(image: left)
        let rightBase64 = try encode(image: right)

        let systemPrompt = """
        You are an expert skin-analysis assistant.
        You receive exactly 3 images in this order:
        1) front face view
        2) left face view
        3) right face view
        Analyze all three views together before producing a result.
        Return ONLY valid JSON, no markdown, no comments, no extra text.
        All string values in the JSON must be in English only.
        """

        let userPrompt = """
        Analyze the skin across ALL three face angles and produce one combined report.
        If image quality is imperfect, provide a conservative best-effort estimate.

        Return:
        - overallScore (0-100)
        - overallSubtitle (short, user-friendly phrase in English)
        - metrics: acne, pores, wrinkles, melanin, radiance, hydration (0-100 each)
        - general fields: skin age range, tone, undertone, type, black spots, acne presence, wrinkles presence, birthmarks (all in English).
        - statuses must be exactly "Present" or "Not Present"

        Output JSON with this exact schema:
        {
          "overallScore": Int,
          "overallSubtitle": String,
          "metrics": {
            "acne": Int,
            "pores": Int,
            "wrinkles": Int,
            "melanin": Int,
            "radiance": Int,
            "hydration": Int
          },
          "general": {
            "skinAge": String,
            "skinTone": String,
            "skinUndertone": String,
            "skinType": String,
            "blackSpots": "Present" | "Not Present",
            "acne": "Present" | "Not Present",
            "wrinkles": "Present" | "Not Present",
            "birthmarks": "Present" | "Not Present"
          }
        }
        """

        let requestPayload = ChatCompletionsRequest(
            model: AppData.OpenAI.model,
            messages: [
                .init(role: "system", content: .text(systemPrompt)),
                .init(role: "user", content: .multi([
                    .text(userPrompt),
                    .image("data:image/jpeg;base64,\(frontBase64)"),
                    .image("data:image/jpeg;base64,\(leftBase64)"),
                    .image("data:image/jpeg;base64,\(rightBase64)")
                ]))
            ],
            temperature: 0.2,
            responseFormat: .jsonObject
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppData.OpenAI.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAISkinAnalyzerError.invalidResponse
        }

        let completion = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw OpenAISkinAnalyzerError.invalidResponse
        }

        guard let jsonData = content.data(using: .utf8) else {
            throw OpenAISkinAnalyzerError.invalidJSON
        }

        let payload = try JSONDecoder().decode(LLMSkinReportPayload.self, from: jsonData)
        return payload.toDomainReport()
    }

    private func encode(image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw OpenAISkinAnalyzerError.invalidResponse
        }
        return data.base64EncodedString()
    }
}

private struct LLMSkinReportPayload: Decodable {
    struct Metrics: Decodable {
        let acne: Int?
        let pores: Int?
        let wrinkles: Int?
        let melanin: Int?
        let radiance: Int?
        let hydration: Int?
    }

    struct General: Decodable {
        let skinAge: String
        let skinTone: String
        let skinUndertone: String
        let skinType: String
        let blackSpots: String
        let acne: String
        let wrinkles: String
        let birthmarks: String
    }

    let overallScore: Int
    let overallSubtitle: String
    let metrics: Metrics
    let general: General

    func toDomainReport() -> SkinReport {
        SkinReport(
            createdAt: Date(),
            overallScore: max(0, min(100, overallScore)),
            overallTitle: "Skin Overall",
            overallSubtitle: overallSubtitle,
            metrics: [
                .init(id: "acne", title: "Acne", score: clamp(metrics.acne ?? 0), colorHex: "F64F4F"),
                .init(id: "pores", title: "Pores", score: clamp(metrics.pores ?? 0), colorHex: "039EFF"),
                .init(id: "wrinkles", title: "Wrinkles", score: clamp(metrics.wrinkles ?? 0), colorHex: "C179FF"),
                .init(id: "melanin", title: "Melanin", score: clamp(metrics.melanin ?? 0), colorHex: "F192E4"),
                .init(id: "radiance", title: "Radiance", score: clamp(metrics.radiance ?? 0), colorHex: "FFC803"),
                .init(id: "hydration", title: "Hydration", score: clamp(metrics.hydration ?? 0), colorHex: "0BAE79")
            ],
            generalFields: [
                .init(id: "skin_age", label: "Skin Age", value: general.skinAge, status: .neutral),
                .init(id: "skin_tone", label: "Skin Tone", value: general.skinTone, status: .neutral),
                .init(id: "skin_undertone", label: "Skin Undertone", value: general.skinUndertone, status: .neutral),
                .init(id: "skin_type", label: "Skin Type", value: general.skinType, status: .neutral),
                .init(id: "black_spots", label: "Black Spots", value: general.blackSpots, status: status(from: general.blackSpots)),
                .init(id: "acne_presence", label: "Acne", value: general.acne, status: status(from: general.acne)),
                .init(id: "wrinkles_presence", label: "Wrinkles", value: general.wrinkles, status: status(from: general.wrinkles)),
                .init(id: "birthmarks", label: "Birthmarks", value: general.birthmarks, status: status(from: general.birthmarks))
            ]
        )
    }

    private func clamp(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    private func status(from value: String) -> SkinReport.GeneralField.Status {
        value.lowercased().contains("not") ? .notPresent : .present
    }
}

private struct ChatCompletionsRequest: Encodable {
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
                enum CodingKeys: String, CodingKey { case url }
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
            switch self {
            case .text(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .multi(let parts):
                var container = encoder.singleValueContainer()
                try container.encode(parts)
            }
        }
    }

    struct ResponseFormat: Encodable {
        let type: String
        static let jsonObject = ResponseFormat(type: "json_object")
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }

    let choices: [Choice]
}
