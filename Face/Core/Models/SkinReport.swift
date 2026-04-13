import Foundation

struct SkinReport: Codable {
    struct Metric: Codable, Identifiable {
        let id: String
        let title: String
        let score: Int
        let colorHex: String
    }

    struct GeneralField: Codable, Identifiable {
        enum Status: String, Codable {
            case present
            case notPresent
            case neutral
        }

        let id: String
        let label: String
        let value: String
        let status: Status?
    }

    let createdAt: Date
    let overallScore: Int
    let overallTitle: String
    let overallSubtitle: String
    let metrics: [Metric]
    let generalFields: [GeneralField]

    static var placeholder: SkinReport {
        SkinReport(
            createdAt: Date(),
            overallScore: 50,
            overallTitle: "Skin Overall",
            overallSubtitle: "Your skin needs more care",
            metrics: [
                .init(id: "acne", title: "Acne", score: 65, colorHex: "F64F4F"),
                .init(id: "pores", title: "Pores", score: 65, colorHex: "039EFF"),
                .init(id: "wrinkles", title: "Wrinkles", score: 75, colorHex: "C179FF"),
                .init(id: "melanin", title: "Melanin", score: 85, colorHex: "F192E4"),
                .init(id: "radiance", title: "Radiance", score: 60, colorHex: "FFC803"),
                .init(id: "hydration", title: "Hydration", score: 85, colorHex: "0BAE79")
            ],
            generalFields: [
                .init(id: "age", label: "Skin Age", value: "~ 25-30", status: .neutral),
                .init(id: "tone", label: "Skin Tone", value: "White", status: .neutral),
                .init(id: "undertone", label: "Skin Undertone", value: "Neutral warm", status: .neutral),
                .init(id: "type", label: "Skin Type", value: "Combination", status: .neutral),
                .init(id: "black_spots", label: "Black Spots", value: "Not Present", status: .notPresent),
                .init(id: "acne_presence", label: "Acne", value: "Present", status: .present),
                .init(id: "wrinkles_presence", label: "Wrinkles", value: "Present", status: .present),
                .init(id: "birthmarks", label: "Birthmarks", value: "Not Present", status: .notPresent)
            ]
        )
    }
}

enum SkinReportStore {
    private static let maxHistoryItems = 100

    static func save(_ report: SkinReport) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        UserDefaults.standard.set(data, forKey: AppData.StorageKeys.latestReportData)

        var history = loadHistory()
        history.removeAll { Calendar.current.isDate($0.createdAt, equalTo: report.createdAt, toGranularity: .second) }
        history.insert(report, at: 0)
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        let historyData = try encoder.encode(history)
        UserDefaults.standard.set(historyData, forKey: AppData.StorageKeys.reportHistoryData)
    }

    static func loadLatest() -> SkinReport? {
        guard let data = UserDefaults.standard.data(forKey: AppData.StorageKeys.latestReportData) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SkinReport.self, from: data)
    }

    static func loadHistory() -> [SkinReport] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var history: [SkinReport] = []
        if let data = UserDefaults.standard.data(forKey: AppData.StorageKeys.reportHistoryData),
           let decoded = try? decoder.decode([SkinReport].self, from: data) {
            history = decoded
        }

        if let latest = loadLatest(),
           !history.contains(where: { Calendar.current.isDate($0.createdAt, equalTo: latest.createdAt, toGranularity: .second) }) {
            history.insert(latest, at: 0)
        }

        return history.sorted { $0.createdAt > $1.createdAt }
    }
}
