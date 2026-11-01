import Foundation
import UIKit

/// ✨ Google Gemini 多模態模型 (實作統一 ShiftLanguageModel 協定，預設 gemini-3.8-flash)
public struct GeminiLanguageModel: ShiftLanguageModel {
    public let modelIdentifier: String
    public let displayName: String
    public let supportsMultimodalVision = true
    private let apiKey: String

    public init(modelName: String, apiKey: String) {
        let clean = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelIdentifier = clean.isEmpty ? ShiftPayConstants.defaultAIModel : clean
        self.displayName = "✨ Gemini (\(self.modelIdentifier))"
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func extractShifts(
        images: [UIImage],
        ocrContext: VisionTableOCRResult,
        context: ScheduleExtractionContext
    ) async throws -> [ExtractedShiftRow] {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiLanguageModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "請先至「設定」填寫 Gemini API Key，或切換為 Apple 內建 Foundation Models 離線模式"])
        }

        let prompt = SchedulePromptBuilder.buildSystemAndUserPrompt(
            context: context,
            imageCount: images.count,
            ocrResult: ocrContext
        )

        var parts: [[String: Any]] = [["text": prompt]]
        for img in images {
            if let jpeg = compressImage(img, maxDim: 1600, quality: 0.84) {
                parts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": jpeg.base64EncodedString()
                    ]
                ])
            }
        }

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]

        // 優先呼叫使用者指定的模型 (預設 gemini-3.8-flash)；若端點回傳 404 則自動嘗試相容後綴
        var candidateModels = [modelIdentifier]
        for fallback in ["gemini-3.8-flash", "gemini-3.8-flash-preview", "gemini-3-flash-preview", "gemini-2.5-flash"] {
            if !candidateModels.contains(fallback) {
                candidateModels.append(fallback)
            }
        }

        let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        var lastErrorMsg = "未知錯誤"
        var lastStatus = 500

        for candidate in candidateModels {
            let encodedModel = candidate.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? candidate
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent?key=\(encodedKey)") else {
                continue
            }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 60
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: req)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 500
            lastStatus = httpStatus

            if (200...299).contains(httpStatus) {
                guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = root["candidates"] as? [[String: Any]],
                      let firstContent = candidates.first?["content"] as? [String: Any],
                      let resParts = firstContent["parts"] as? [[String: Any]] else {
                    throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "AI 沒有回傳有效內容"])
                }

                let nonThought = resParts.compactMap { part -> String? in
                    if (part["thought"] as? Bool) == true { return nil }
                    return part["text"] as? String
                }.joined()
                let text = nonThought.isEmpty ? resParts.compactMap { $0["text"] as? String }.joined() : nonThought

                return try ScheduleJSONParser.parseRows(from: text, year: context.year, month: context.month)
            }

            let errJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            let errObj = errJson?["error"] as? [String: Any]
            lastErrorMsg = (errObj?["message"] as? String) ?? "HTTP \(httpStatus)"

            // 若非 404 (例如 API Key 錯誤 400/403 或 429)，不需繼續嘗試其他模型名稱
            if httpStatus != 404 {
                break
            }
        }

        throw NSError(domain: "Gemini", code: lastStatus, userInfo: [NSLocalizedDescriptionKey: lastErrorMsg])
    }

    private func compressImage(_ image: UIImage, maxDim: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return image.jpegData(compressionQuality: quality) }
        let ratio = min(1.0, maxDim / max(size.width, size.height))
        let targetSize = CGSize(width: round(size.width * ratio), height: round(size.height * ratio))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
