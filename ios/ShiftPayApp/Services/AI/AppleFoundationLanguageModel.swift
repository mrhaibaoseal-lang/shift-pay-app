import Foundation
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

public struct AppleFoundationLanguageModel: ShiftLanguageModel {
    public let modelIdentifier = "apple-foundation-ondevice-v27"
    public let displayName = "🍎 Apple Foundation Models + Vision (裝置端)"
    public let supportsMultimodalVision = true

    public init() {}

    public func extractShifts(
        images: [UIImage],
        ocrContext: VisionTableOCRResult,
        context: ScheduleExtractionContext
    ) async throws -> [ExtractedShiftRow] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let rows = try? await invokeNativeFoundationModel(ocrContext: ocrContext, context: context), !rows.isEmpty {
                return rows
            }
        }
        #endif

        let parsed = parseFromVisionOCR(ocr: ocrContext, context: context)
        if parsed.isEmpty {
            throw NSError(
                domain: "AppleFoundationModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Vision 離線掃描未在照片中找到「\(context.employeeName)」對應的明確時間格。若為極度潦草手寫表，建議於設定輸入 Gemini API Key 使用「⚡ DynamicProfile 智慧混合」模式。"]
            )
        }
        return parsed
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func invokeNativeFoundationModel(
        ocrContext: VisionTableOCRResult,
        context: ScheduleExtractionContext
    ) async throws -> [ExtractedShiftRow] {
        let session = LanguageModelSession()
        let prompt = SchedulePromptBuilder.buildSystemAndUserPrompt(
            context: context,
            imageCount: ocrContext.pageCount,
            ocrResult: ocrContext
        )
        let response = try await session.respond(to: prompt)
        return try ScheduleJSONParser.parseRows(from: response.content, year: context.year, month: context.month)
    }
    #endif

    private func parseFromVisionOCR(ocr: VisionTableOCRResult, context: ScheduleExtractionContext) -> [ExtractedShiftRow] {
        var byDate: [String: ExtractedShiftRow] = [:]

        // 1. 優先從 7 欄式月曆方格 (星期一~星期日) 掃描「弘 + 早/晚/整」代號
        for cell in ocr.calendarCells {
            guard let shiftCode = cell.detectedShiftCode else { continue }
            let dateKey = PayrollEngine.dateKey(year: context.year, month: context.month, day: cell.day)
            if let resolved = ScheduleJSONParser.resolveShiftCode(codeOrNote: shiftCode, dateKey: dateKey) {
                byDate[dateKey] = ExtractedShiftRow(
                    date: dateKey,
                    startTime: resolved.startTime,
                    endTime: resolved.endTime,
                    breakMin: resolved.breakMin,
                    shiftLabel: resolved.shiftLabel,
                    note: cell.normalizedCellText,
                    checked: true,
                    needsReview: false
                )
            }
        }

        if !byDate.isEmpty {
            return byDate.values.sorted { $0.date < $1.date }
        }

        // 2. 若非月曆代號表，回退掃描數字時間段 (如 10:30-21:00)
        let sourceLines = ocr.matchedEmployeeRowTexts.isEmpty
            ? ocr.fullRecognizedText.components(separatedBy: .newlines)
            : ocr.matchedEmployeeRowTexts
        let dim = PayrollEngine.daysInMonth(year: context.year, month: context.month)
        let pattern = #"(\d{1,2})(?::(\d{2})|半)?\s*[-~～至]\s*(\d{1,2})(?::(\d{2})|半)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var results: [ExtractedShiftRow] = []
        var dayCursor = 1

        for line in sourceLines {
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for m in matches {
                guard dayCursor <= dim else { break }
                let rawToken = nsLine.substring(with: m.range)
                if let (st, et) = ScheduleJSONParser.normalizeHandwrittenTimeRange(rawToken) {
                    let dateStr = PayrollEngine.dateKey(year: context.year, month: context.month, day: dayCursor)
                    let brk = (st == "10:30" && et == "21:00") ? 120 : 0
                    results.append(
                        ExtractedShiftRow(
                            date: dateStr,
                            startTime: st,
                            endTime: et,
                            breakMin: brk,
                            shiftLabel: brk == 120 ? "整天班" : "",
                            note: "Vision: \(rawToken)",
                            checked: true,
                            needsReview: rawToken.contains("?")
                        )
                    )
                    dayCursor += 1
                }
            }
        }
        return results
    }
}
