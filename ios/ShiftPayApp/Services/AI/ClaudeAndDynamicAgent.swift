import Foundation
import UIKit

/// 🤖 Anthropic Claude 多模態模型 + iOS 27 DynamicProfile 智慧路由器
public struct ClaudeLanguageModel: ShiftLanguageModel {
    public let modelIdentifier: String
    public let displayName: String
    public let supportsMultimodalVision = true
    private let apiKey: String

    public init(modelName: String = ShiftPayConstants.defaultClaudeModel, apiKey: String) {
        let clean = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelIdentifier = clean.isEmpty ? ShiftPayConstants.defaultClaudeModel : clean
        self.displayName = "🤖 Claude (\(self.modelIdentifier))"
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func extractShifts(
        images: [UIImage],
        ocrContext: VisionTableOCRResult,
        context: ScheduleExtractionContext
    ) async throws -> [ExtractedShiftRow] {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "ClaudeLanguageModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "請先於設定中輸入 Claude API Key"])
        }

        let prompt = SchedulePromptBuilder.buildSystemAndUserPrompt(
            context: context,
            imageCount: images.count,
            ocrResult: ocrContext
        )

        var contentBlocks: [[String: Any]] = []
        for img in images {
            if let jpeg = img.jpegData(compressionQuality: 0.82) {
                contentBlocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": jpeg.base64EncodedString()
                    ]
                ])
            }
        }
        contentBlocks.append(["type": "text", "text": prompt])

        let body: [String: Any] = [
            "model": modelIdentifier,
            "max_tokens": 2048,
            "temperature": 0.1,
            "messages": [
                ["role": "user", "content": contentBlocks]
            ]
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 60
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 500
        if !(200...299).contains(httpStatus) {
            throw NSError(domain: "Claude", code: httpStatus, userInfo: [NSLocalizedDescriptionKey: "Claude API 回應錯誤 (HTTP \(httpStatus))"])
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw NSError(domain: "Claude", code: 500, userInfo: [NSLocalizedDescriptionKey: "Claude 未回傳有效文字"])
        }

        return try ScheduleJSONParser.parseRows(from: text, year: context.year, month: context.month)
    }
}

/// ⚡ iOS 27 DynamicProfile Session 協調器 (動態切換 Vision OCRTool、Apple Foundation Models、Gemini 與 Claude)
@MainActor
public final class DynamicProfileScheduleAgent {
    public static let shared = DynamicProfileScheduleAgent()

    private init() {}

    public func recognizeMultiPageSchedule(
        images: [UIImage],
        year: Int,
        month: Int,
        settings: PayrollSettings,
        stamps: [ShiftStamp],
        onStageChanged: @escaping (String) -> Void
    ) async throws -> [ExtractedShiftRow] {
        let context = ScheduleExtractionContext(
            year: year,
            month: month,
            employeeName: settings.myName,
            codeHints: settings.codeHints,
            stamps: stamps
        )

        // Stage 1: DynamicProfile [LocatorProfile] -> 呼叫內建 Vision OCRTool 定位表格列與姓名
        onStageChanged("🔍 DynamicProfile [1/2]：正在執行 Apple Vision OCRTool 空間表格對齊，尋找「\(settings.myName)」…")
        let ocrResult = await VisionOCRTool.scanScheduleTables(images: images, targetName: settings.myName)

        // Stage 2: DynamicProfile [ExtractionProfile] -> 動態切換至目標 LanguageModel
        let activeModel: any ShiftLanguageModel
        switch settings.aiProvider {
        case .appleFoundation:
            activeModel = AppleFoundationLanguageModel()
        case .gemini:
            activeModel = GeminiLanguageModel(modelName: settings.aiModel, apiKey: settings.apiKey)
        case .claude:
            activeModel = ClaudeLanguageModel(modelName: settings.aiModel, apiKey: settings.claudeApiKey.isEmpty ? settings.apiKey : settings.claudeApiKey)
        case .hybridDynamic:
            // 若已設定 Gemini API Key，自動結合 Vision OCR 定位 + Gemini 多模態視覺；否則自動切換為 Apple 內建 Foundation Models
            if !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeModel = GeminiLanguageModel(modelName: settings.aiModel, apiKey: settings.apiKey)
            } else {
                activeModel = AppleFoundationLanguageModel()
            }
        }

        onStageChanged("🧠 DynamicProfile [2/2]：已切換至 \(activeModel.displayName)，正在跨頁合併 \(images.count) 張班表…")
        return try await activeModel.extractShifts(images: images, ocrContext: ocrResult, context: context)
    }
}
