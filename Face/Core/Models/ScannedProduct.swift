import Foundation
import UIKit

enum ProductSuitability: String, Codable, Equatable {
    case suitable = "suitable"
    case notSuitable = "not_suitable"
    case unknown = "unknown"
}

enum ProductIngredientVerdict: String, Codable, Equatable {
    case safe
    case caution
    case unsafe
}

struct ProductIngredientAnalysis: Identifiable, Codable, Equatable {
    let name: String
    let details: String
    let verdict: ProductIngredientVerdict

    var id: String {
        "\(name.lowercased())|\(verdict.rawValue)|\(details.lowercased())"
    }
}

struct ProductAnalysis: Codable, Equatable {
    let isFaceProduct: Bool
    let rejectionReason: String?
    let productName: String
    let brand: String
    let category: String
    let suitability: ProductSuitability
    let suitabilityScore: Int
    let suitabilitySummary: String
    let pros: [String]
    let cons: [String]
    let howToUse: [String]
    let warnings: [String]
    let ingredients: [ProductIngredientAnalysis]
}

struct ProductUserProfile {
    let age: Int?
    let skinType: String
    let skinTone: String
    let skinUndertone: String
}

struct ScannedProduct: Identifiable, Codable, Equatable {
    enum AnalysisState: Codable, Equatable {
        case analyzing
        case completed(ProductAnalysis)
        case failed(String)

        private enum CodingKeys: String, CodingKey {
            case kind
            case analysis
            case message
        }

        private enum Kind: String, Codable {
            case analyzing
            case completed
            case failed
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: .kind)
            switch kind {
            case .analyzing:
                self = .analyzing
            case .completed:
                let analysis = try container.decode(ProductAnalysis.self, forKey: .analysis)
                self = .completed(analysis)
            case .failed:
                let message = try container.decode(String.self, forKey: .message)
                self = .failed(message)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .analyzing:
                try container.encode(Kind.analyzing, forKey: .kind)
            case .completed(let analysis):
                try container.encode(Kind.completed, forKey: .kind)
                try container.encode(analysis, forKey: .analysis)
            case .failed(let message):
                try container.encode(Kind.failed, forKey: .kind)
                try container.encode(message, forKey: .message)
            }
        }
    }

    let id: UUID
    let createdAt: Date
    let imageData: Data
    var title: String
    var brand: String
    var category: String
    var isFavorite: Bool
    var analysisState: AnalysisState

    var canOpenDetails: Bool {
        guard case .completed(let analysis) = analysisState else { return false }
        return analysis.isFaceProduct
    }

    var recommendationColorHex: String {
        guard case .completed(let analysis) = analysisState else { return "939393" }
        switch analysis.suitability {
        case .suitable:
            return "0BAE79"
        case .notSuitable:
            return "F64F4F"
        case .unknown:
            return "FF8503"
        }
    }

    var recommendationSymbolName: String {
        guard case .completed(let analysis) = analysisState else { return "hourglass" }
        switch analysis.suitability {
        case .suitable:
            return "hand.thumbsup.fill"
        case .notSuitable:
            return "hand.thumbsdown.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var statusText: String {
        switch analysisState {
        case .analyzing:
            return "Analysis in progress..."
        case .failed(let message):
            return message
        case .completed(let analysis):
            if analysis.isFaceProduct {
                return analysis.suitabilitySummary
            }
            return analysis.rejectionReason ?? "This doesn't look like a supported head or face beauty product."
        }
    }

    static func pending(from image: UIImage) -> ScannedProduct {
        let imageData = image.jpegData(compressionQuality: 0.86) ?? Data()
        return ScannedProduct(
            id: UUID(),
            createdAt: Date(),
            imageData: imageData,
            title: "Analyzing Product...",
            brand: "Please wait",
            category: "Pending",
            isFavorite: false,
            analysisState: .analyzing
        )
    }
}

extension ScannedProduct {
    static var previewCompleted: ScannedProduct {
        let imageData = UIImage(systemName: "photo")?.pngData() ?? Data()
        let analysis = ProductAnalysis(
            isFaceProduct: true,
            rejectionReason: nil,
            productName: "CeraVe Moisturizing Cream",
            brand: "CeraVe",
            category: "Skincare",
            suitability: .suitable,
            suitabilityScore: 85,
            suitabilitySummary: "Suitable for dry and sensitive skin profile.",
            pros: [
                "Hydrates deeply",
                "Supports skin barrier"
            ],
            cons: [
                "May feel heavy on oily skin"
            ],
            howToUse: [
                "Apply on clean skin",
                "Use morning and evening"
            ],
            warnings: [
                "Patch test before first use"
            ],
            ingredients: [
                .init(name: "Ceramides", details: "Supports skin barrier.", verdict: .safe),
                .init(name: "Hyaluronic Acid", details: "Hydrates skin.", verdict: .safe)
            ]
        )
        return ScannedProduct(
            id: UUID(),
            createdAt: Date(),
            imageData: imageData,
            title: analysis.productName,
            brand: analysis.brand,
            category: analysis.category,
            isFavorite: true,
            analysisState: .completed(analysis)
        )
    }
}

enum ScannedProductStore {
    private static let maxHistoryItems = 500

    static func save(_ products: [ScannedProduct]) {
        let capped = Array(products.prefix(maxHistoryItems))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(capped) else { return }
        UserDefaults.standard.set(data, forKey: AppData.StorageKeys.scannedProductsData)
    }

    static func load() -> [ScannedProduct] {
        guard let data = UserDefaults.standard.data(forKey: AppData.StorageKeys.scannedProductsData) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([ScannedProduct].self, from: data)) ?? []
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: AppData.StorageKeys.scannedProductsData)
    }
}
