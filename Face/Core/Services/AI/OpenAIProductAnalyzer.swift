import Foundation
import UIKit

enum OpenAIProductAnalyzerError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidJSON
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OPENAI_API_KEY is missing."
        case .invalidResponse:
            return "Unable to analyze this photo right now."
        case .invalidJSON:
            return "Unexpected analysis format."
        case .emptyReply:
            return "OpenAI returned an empty response."
        }
    }
}

struct OpenAIProductAnalyzer {
    func analyze(image: UIImage, profile: ProductUserProfile) async throws -> ProductAnalysis {
        guard !AppData.OpenAI.apiKey.isEmpty else {
            throw OpenAIProductAnalyzerError.missingAPIKey
        }

        guard let imageData = image.jpegData(compressionQuality: 0.82) else {
            throw OpenAIProductAnalyzerError.invalidResponse
        }

        let base64 = imageData.base64EncodedString()
        let profileSummary = """
        User profile:
        - Age: \(profile.age.map(String.init) ?? "unknown")
        - Skin type: \(normalized(profile.skinType))
        - Skin tone: \(normalized(profile.skinTone))
        - Skin undertone: \(normalized(profile.skinUndertone))
        """

        let systemPrompt = """
        You are a cosmetic product analysis assistant.
        Analyze ONLY one uploaded image of a product.

        Your job:
        1) Decide whether this is a HEAD/FACE beauty product.
        Treat isFaceProduct=true for:
        - Face skincare (cleanser, toner, serum, moisturizer, SPF, treatment, masks, blackhead care, pore care)
        - Face makeup (foundation, concealer, powder, blush/cheek, contour, highlighter)
        - Eye area beauty products (mascara, eyeliner, eyeshadow, brow products, eye creams)
        - Lip products (lipstick, lip balm, lip mask, lip treatment)
        - Scalp and hair beauty products for the head (shampoo, conditioner, hair mask, scalp treatment, styling)
        - Ear-area cosmetic/beauty care when clearly part of beauty grooming
        2) Treat isFaceProduct=false for non-beauty or unrelated categories:
        - Body-only products for hands/arms/legs/feet
        - Pets, food, electronics, tools, household items, random objects
        - Anything that is not clearly a head/face beauty product
        3) If isFaceProduct=false, return a concise rejectionReason.
        4) If isFaceProduct=true, provide practical and specific analysis.
        5) Always use the provided user profile as the main personalization context for suitability decision and suitabilitySummary.
           If profile values are unknown, proceed conservatively and explicitly reflect that uncertainty.

        Return ONLY valid JSON. No markdown. No extra text.
        All textual content in the JSON must be in English only.
        """

        let userPrompt = """
        \(profileSummary)

        Analyze this product image and return JSON with EXACT schema:
        {
          "isFaceProduct": Bool,
          "rejectionReason": String,
          "productName": String,
          "brand": String,
          "category": String,
          "suitability": "suitable" | "not_suitable" | "unknown",
          "suitabilityScore": Int,
          "suitabilitySummary": String,
          "pros": [String],
          "cons": [String],
          "howToUse": [String],
          "warnings": [String],
          "ingredients": [
            {
              "name": String,
              "details": String,
              "verdict": "safe" | "caution" | "unsafe"
            }
          ]
        }

        Rules:
        - suitabilityScore must be 0...100.
        - If isFaceProduct=false: fill rejectionReason, keep product fields best-effort (or empty), and arrays may be empty.
        - Be strict: if unsure whether it's a head/face beauty product, set isFaceProduct=false.
        - suitability and suitabilitySummary must explicitly consider the provided profile (age, skin type, tone, undertone).
        - If unsure about any field, use conservative "unknown" style values.
        - Keep each list item concise and actionable.
        - Use English only for all text fields and list items.
        """

        let payload = ProductChatCompletionsRequest(
            model: AppData.OpenAI.model,
            messages: [
                .init(role: "system", content: .text(systemPrompt)),
                .init(role: "user", content: .multi([
                    .text(userPrompt),
                    .image("data:image/jpeg;base64,\(base64)")
                ]))
            ],
            temperature: 0.2,
            responseFormat: .jsonObject
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppData.OpenAI.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenAIProductAnalyzerError.invalidResponse
        }

        let completion = try JSONDecoder().decode(ProductChatCompletionsResponse.self, from: data)
        let content = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else {
            throw OpenAIProductAnalyzerError.emptyReply
        }
        guard let jsonData = content.data(using: .utf8) else {
            throw OpenAIProductAnalyzerError.invalidJSON
        }

        let llm = try JSONDecoder().decode(LLMProductAnalysisPayload.self, from: jsonData)
        return llm.toDomain()
    }

    private func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : trimmed
    }
}

private struct LLMProductAnalysisPayload: Decodable {
    struct Ingredient: Decodable {
        let name: String
        let details: String
        let verdict: String
    }

    let isFaceProduct: Bool?
    let rejectionReason: String?
    let productName: String?
    let brand: String?
    let category: String?
    let suitability: String?
    let suitabilityScore: Int?
    let suitabilitySummary: String?
    let pros: [String]?
    let cons: [String]?
    let howToUse: [String]?
    let warnings: [String]?
    let ingredients: [Ingredient]?

    func toDomain() -> ProductAnalysis {
        let isFaceProduct = self.isFaceProduct ?? false
        let suitability = Self.mapSuitability(suitability)
        let score = max(0, min(100, suitabilityScore ?? 0))
        let summary = Self.sanitize(
            suitabilitySummary,
            fallback: isFaceProduct
                ? "Best-effort estimate based on visible product info."
                : "This doesn't look like a supported head or face beauty product."
        )

        let mappedIngredients: [ProductIngredientAnalysis] = (ingredients ?? []).map { item in
            ProductIngredientAnalysis(
                name: Self.sanitize(item.name, fallback: "Unknown ingredient"),
                details: Self.sanitize(item.details, fallback: "No details available."),
                verdict: Self.mapVerdict(item.verdict)
            )
        }

        return ProductAnalysis(
            isFaceProduct: isFaceProduct,
            rejectionReason: Self.sanitize(rejectionReason, fallback: "This item is not a supported head or face beauty product. Please scan face/lip/eye/scalp/hair beauty products."),
            productName: Self.sanitize(productName, fallback: isFaceProduct ? "Unknown Face Product" : "Unsupported Item"),
            brand: Self.sanitize(brand, fallback: isFaceProduct ? "Unknown Brand" : "Unrecognized"),
            category: Self.sanitize(category, fallback: isFaceProduct ? "Skincare" : "Unsupported"),
            suitability: suitability,
            suitabilityScore: score,
            suitabilitySummary: summary,
            pros: Self.cleanedList(pros),
            cons: Self.cleanedList(cons),
            howToUse: Self.cleanedList(howToUse),
            warnings: Self.cleanedList(warnings),
            ingredients: mappedIngredients
        )
    }

    private static func mapSuitability(_ raw: String?) -> ProductSuitability {
        switch (raw ?? "").lowercased() {
        case "suitable":
            return .suitable
        case "not_suitable":
            return .notSuitable
        default:
            return .unknown
        }
    }

    private static func mapVerdict(_ raw: String) -> ProductIngredientVerdict {
        switch raw.lowercased() {
        case "safe":
            return .safe
        case "unsafe":
            return .unsafe
        default:
            return .caution
        }
    }

    private static func sanitize(_ value: String?, fallback: String) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func cleanedList(_ value: [String]?) -> [String] {
        let cleaned = (value ?? []).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        return cleaned
    }
}

private struct ProductChatCompletionsRequest: Encodable {
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
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let value):
                try container.encode(value)
            case .multi(let parts):
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

private struct ProductChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }

    let choices: [Choice]
}
