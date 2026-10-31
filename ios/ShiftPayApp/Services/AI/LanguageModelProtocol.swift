import Foundation
import UIKit

/// 統一的 LanguageModel 協定 (對齊 iOS 27 FoundationModels 架構，無縫串接 Apple 裝置端模型、Gemini 與 Claude)
public protocol ShiftLanguageModel: Sendable {
    var modelIdentifier: String { get }
    var displayName: String { get }
    var supportsMultimodalVision: Bool { get }

    func extractShifts(
        images: [UIImage],
        ocrContext: VisionTableOCRResult,
        context: ScheduleExtractionContext
    ) async throws -> [ExtractedShiftRow]
}

/// 班表辨識上下文與工具參數
public struct ScheduleExtractionContext: Sendable {
    public let year: Int
    public let month: Int
    public let employeeName: String
    public let codeHints: String
    public let stamps: [ShiftStamp]

    public init(year: Int, month: Int, employeeName: String, codeHints: String, stamps: [ShiftStamp]) {
        self.year = year
        self.month = month
        self.employeeName = employeeName
        self.codeHints = codeHints
        self.stamps = stamps
    }
}

/// Vision OCRTool 辨識出的表格列與文字結果
public struct VisionTableOCRResult: Sendable {
    public let fullRecognizedText: String
    public let matchedEmployeeRowTexts: [String]
    public let pageCount: Int

    public init(fullRecognizedText: String, matchedEmployeeRowTexts: [String], pageCount: Int) {
        self.fullRecognizedText = fullRecognizedText
        self.matchedEmployeeRowTexts = matchedEmployeeRowTexts
        self.pageCount = pageCount
    }
}

/// iOS 27 DynamicProfile：支援在同一個辨識對話階段動態切換模型、指令與工具 (Vision OCRTool + ShiftRuleLookupTool)
public struct LanguageModelDynamicProfile: Sendable {
    public let profileName: String
    public let systemInstructions: String
    public let enableVisionOCRTool: Bool
    public let enableShiftRuleTool: Bool

    public init(
        profileName: String,
        systemInstructions: String,
        enableVisionOCRTool: Bool = true,
        enableShiftRuleTool: Bool = true
    ) {
        self.profileName = profileName
        self.systemInstructions = systemInstructions
        self.enableVisionOCRTool = enableVisionOCRTool
        self.enableShiftRuleTool = enableShiftRuleTool
    }
}

/// 產生與 Web V2 100% 對齊並結合 Vision 表格定位與常用印章代號的跨頁合併 Prompt
public enum SchedulePromptBuilder {
    public static func buildSystemAndUserPrompt(
        context: ScheduleExtractionContext,
        imageCount: Int,
        ocrResult: VisionTableOCRResult? = nil
    ) -> String {
        let dim = PayrollEngine.daysInMonth(year: context.year, month: context.month)
        let firstKey = PayrollEngine.dateKey(year: context.year, month: context.month, day: 1)
        let firstWd = ShiftPayConstants.weekDays[PayrollEngine.weekdayIndex(of: firstKey)]

        let short2 = String(context.employeeName.suffix(2))
        let short1 = String(context.employeeName.suffix(1))

        let stampRules = context.stamps.map { "\($0.name): \($0.start)-\($0.end)" }.joined(separator: "、")
        let hintsText = context.codeHints.isEmpty ? "（無特別說明，請依常理與常用班別判斷）" : context.codeHints

        var ocrAssistBlock = ""
        if let ocr = ocrResult, !ocr.fullRecognizedText.isEmpty {
            let matchedLines = ocr.matchedEmployeeRowTexts.joined(separator: "\n")
            ocrAssistBlock = """

            【Apple Vision OCRTool 空間表格預掃描輔助資訊】
            系統已先透過裝置端 Vision 框架掃描表格文字：
            - 疑似「\(context.employeeName)」所在列文字：
            \(matchedLines.isEmpty ? "（請直接由圖片視覺判讀）" : matchedLines)
            """
        }

        return """
        你是一位專精辨識「餐飲/零售店主管手寫排班表」的資料擷取助理。

        【多圖跨頁合併核心指令】
        使用者上傳了多張手寫班表照片（目前共 \(max(1, imageCount)) 張），這些是同一個月份不同頁數（例如上半月與下半月、或不同週次）的班表。請綜合讀取所有照片，找出姓名為『\(context.employeeName)』在每一頁中的所有排班，將所有日期的班表**合併、去除重複日期、並按照日期先後順序（1號到月底）由小到大排序**後，統一回傳成一個完整的 JSON 陣列。

        【辨識細節規則】
        1. 表格中通常有多位同事。請只鎖定姓名為「\(context.employeeName)」的那一列（或那一欄）。姓名可能被簡寫成名字、單字或暱稱（例如「\(short2)」「\(short1)」），請依合理性判斷，不要誤抓其他人的班。
        2. 這份班表是 \(context.year) 年 \(context.month) 月（共 \(dim) 天，\(context.month) 月 1 日是星期\(firstWd)）。請把每一格對應到正確日期，輸出格式為 YYYY-MM-DD。
        3. 將手寫時間轉換為標準 24 小時制 "HH:MM"，例如：
           - "18-22" → startTime "18:00"、endTime "22:00"
           - "9-5" 或 "9~5" → "09:00"-"17:00"
           - "10半-7" 或 "10:30-7" → "10:30"-"19:00"
           - "5-12" 晚班若明顯是晚上 → "17:00"-"00:00"
        4. 休假、空白、畫斜線「/」、打「X」、寫「休」「off」「例」「休假」的日期，請不要輸出。
        5. note 欄位請填入該格手寫的原始字樣（例如 "18-22"、"早"、"晚"）；若字跡不確定，請在 note 末尾加上 "(?)"。
        6. 店家手寫代號對照（請優先遵守）：\(hintsText)
        7. 使用者已設定的常用班別參考：\(stampRules.isEmpty ? "無" : stampRules)\(ocrAssistBlock)

        【輸出規則】
        - 只輸出純 JSON 陣列，不要任何說明文字、不要 markdown 程式碼框。
        - 格式：[{"date":"YYYY-MM-DD","startTime":"HH:MM","endTime":"HH:MM","note":"手寫原字樣"}]
        - 必須去除重複日期，並依日期（1號到月底）由小到大排序。若找不到「\(context.employeeName)」，請輸出 []。
        """
    }
}
