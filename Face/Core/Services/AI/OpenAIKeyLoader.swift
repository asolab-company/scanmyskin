import Foundation

enum OpenAIKeyLoader {
    private static let encodedPasteURLDoubleBase64 =
        "YUhSMGNITTZMeTl3WVhOMFpXSnBiaTVqYjIwdmNtRjNMMjVvWjJSeGFUZFI="

    private static func decodePasteURL() -> URL? {
        guard
            let layer1Data = Data(base64Encoded: encodedPasteURLDoubleBase64),
            let layer1String = String(data: layer1Data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let layer2Data = Data(base64Encoded: layer1String),
            let urlString = String(data: layer2Data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let url = URL(string: urlString)
        else {
            return nil
        }
        return url
    }

    @MainActor
    static func ensureKeyLoaded() async {
        if let cached = UserDefaults.standard.string(forKey: AppData.StorageKeys.openAICachedAPIKey),
           !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        if hasBundledOrEnvKey() {
            return
        }

        guard let remoteKeyURL = decodePasteURL() else { return }

        do {
            var request = URLRequest(url: remoteKeyURL)
            request.timeoutInterval = 20
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let raw = String(data: data, encoding: .utf8) else { return }
            guard let key = parseKey(from: raw) else { return }
            UserDefaults.standard.set(key, forKey: AppData.StorageKeys.openAICachedAPIKey)
        } catch {}
    }

    private static func hasBundledOrEnvKey() -> Bool {
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
        let fromEnv = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        return [fromPlist, fromEnv]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { !$0.isEmpty }
    }

    private static func parseKey(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? trimmed
        guard firstLine.hasPrefix("sk-"), firstLine.count > 10 else { return nil }
        return firstLine
    }
}
