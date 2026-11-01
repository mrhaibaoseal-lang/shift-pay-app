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

/// Vision OCRTool 辨識出的表格列與月曆格結果
public struct VisionCalendarCellOCR: Sendable {
    public let day: Int
    public let weekdayColumn: Int // 0 = 週一 ... 6 = 週日
    public let rawCellText: String
    public let normalizedCellText: String
    public let detectedShiftCode: String? // "整" | "晚" | "早"

    public init(day: Int, weekdayColumn: Int, rawCellText: String, normalizedCellText: String, detectedShiftCode: String?) {
        self.day = day
        self.weekdayColumn = weekdayColumn
        self.rawCellText = rawCellText
        self.normalizedCellText = normalizedCellText
        self.detectedShiftCode = detectedShiftCode
    }
}

public struct VisionTableOCRResult: Sendable {
    public let fullRecognizedText: String
    public let matchedEmployeeRowTexts: [String]
    public let calendarCells: [VisionCalendarCellOCR]
    public let pageCount: Int

    public init(
        fullRecognizedText: String,
        matchedEmployeeRowTexts: [String],
        calendarCells: [VisionCalendarCellOCR] = [],
        pageCount: Int
    ) {
        self.fullRecognizedText = fullRecognizedText
        self.matchedEmployeeRowTexts = matchedEmployeeRowTexts
        self.calendarCells = calendarCells
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
        let short1 = String(context.employeeName.suffix(1)).isEmpty ? "弘" : String(context.employeeName.suffix(1))

        let stampRules = context.stamps.map { "\($0.name): \($0.start)-\($0.end)(休\($0.breakMin)m)" }.joined(separator: "、")
        let hintsText = context.codeHints.isEmpty ? ShiftPayConstants.defaultCodeHints : context.codeHints

        var dayCalendarGuide: [String] = []
        for d in 1...dim {
            let dk = PayrollEngine.dateKey(year: context.year, month: context.month, day: d)
            let wdIdx = PayrollEngine.weekdayIndex(of: dk)
            let wdName = ShiftPayConstants.weekDays[wdIdx]
            let isWeekend = (wdIdx == 0 || wdIdx == 6)
            dayCalendarGuide.append("\(d)號(週\(wdName)・\(isWeekend ? "假日" : "平日"))")
        }
        let calendarLookupText = dayCalendarGuide.joined(separator: "、")

        var ocrAssistBlock = ""
        if let ocr = ocrResult, !ocr.calendarCells.isEmpty {
            let cellLines = ocr.calendarCells.map { cell in
                let codeStr = cell.detectedShiftCode.map { " -> 疑似班別:\($0)" } ?? ""
                return "  * \(cell.day)號格: \(cell.normalizedCellText)\(codeStr)"
            }.joined(separator: "\n")
            ocrAssistBlock = """

            【Apple Vision 月曆格預掃描參考（請以圖片視覺為主進行核對）】
            \(cellLines)
            """
        }

        return """
        你是一位專精辨識台灣門市「手寫月曆格排班表」與「多人連寫代號班表」的頂尖視覺擷取專家。

        【核心任務】
        使用者上傳了 \(max(1, imageCount)) 張排班表照片，請找出姓名為『\(context.employeeName)』（在班表上一律簡寫為單字『\(short1)』或『\(short2)』）在 **\(context.year) 年 \(context.month) 月** 的所有排班，合併去重並依日期由小到大排序後回傳 JSON 陣列。

        【⚠️ 極重要：這份手寫排班表的版面與多人連寫規則（必讀）】
        1. **7 欄式月曆方格結構（星期一～星期日）**：
           - 表格上方標題欄由左至右依序為：`星期一 | 星期二 | 星期三 | 星期四 | 星期五 | 星期六 | 星期日`。
           - 每一個方格代表一天，方格**左上角有手寫阿拉伯數字代表幾號**（例如 `4`、`7`、`8`、`11`、`14`、`15`、`16`、`17`、`21`、`24`、`26`、`28`）。
           - 注意：表格第一列或最後一列可能包含上個月底或下個月初的日期（例如右下角寫 `11/1` 代表 11 月 1 日，若目前查詢 10 月則不要混入）。請務必用「所在的星期幾欄位」與下方提供的【當月平假日月曆對照表】雙重驗證日期！
        2. **多人共用班別尾字寫法（最關鍵規則！）**：
           - 店內同事簡稱包含：`\(short1)`（目標本人）、`李`、`鈞`、`語`、`怡`、`呈`、`雲`、`UD`（有時寫成圈起來的 UD 或休）。
           - 店長習慣把「同一天上同種班別的多位同事名字」**連在一起寫在班別代號（`整`、`晚`、`早`、`休`）前面**：
             * **方格上半部**通常寫**整天班（`整`）**或早班（`早`）：
               - 只要該串名字裡包含「**\(short1)**」且結尾是「**整**」，例如：**`\(short1)整`、`\(short1)鈞整`、`鈞\(short1)整`、`李\(short1)整`、`呈\(short1)整`、`UD\(short1)整`、`\(short1)李整`** 👉 全部代表 **「\(short1)」當天要上「整」班（整天班）**！
             * **方格下半部**通常寫**晚班（`晚`）**或休假（`休`）：
               - 只要該串名字裡包含「**\(short1)**」且結尾是「**晚**」，例如：**`\(short1)晚`、`雲休 \(short1)晚`** 👉 代表 **「\(short1)」當天要上「晚」班（晚班）**！
             * **只要包含「\(short1)」且結尾是「早」**（如 `\(short1)早`）👉 代表 **「\(short1)」當天要上「早」班（早班）**！
             * **嚴格排除他人排班（特別注意「怡」與「\(short1)」的區別！）**：
               - 店內有另一位常上晚班的同事叫「**怡**」（左邊是直豎「忄」，右邊是「台」，「台」的下方有一個方框「口」）。
               - 「**\(short1)**」左邊是彎弓「弓」，右邊**只有單一個「厶」，下方絕對沒有「口」**！
               - 因此像 **`怡晚`、`怡語晚`（例如 10/3、10/16 格內寫的是「怡語晚」，不是弘！）、`怡呈晚`、`語怡晚`、`怡整`** 全部是同事「怡」的班，**絕對不是「\(short1)」的班**！
               - 其他無「\(short1)」的字串（如 `鈞整`、`李整`、`呈整`、`UD呈整`、`UD鈞整`、`李UD整`、`鈞呈整`、`呈鈞整`、`呈UD整`、`語呈晚`、`語晚`、`李晚`、`呈晚`、`保齡球`、`消毒`、`外送`、`吃飯`）也全部是其他同事的班，請嚴格排除！
        3. **手寫字跡辨識訣竅**：
           - 手寫的「**\(short1)**」（左弓右厶，下方無口）筆畫連寫時，左邊的「弓」常像數字 `3` 或 `弓`，右邊的「厶」常像 `4` 或 `ム`，尤其寫在日期 `4`、`11`、`14`、`26` 號旁邊或下方時（例如 `4 弘鈞整`、`11 弘鈞整`、`14 弘鈞整`、`26 弘李整`），請仔細看清楚那是人名「**\(short1)**」！
           - 手寫的「**整**」連筆時下半部常像「聖」或「壓」，位於方格上半部人名串的最後一個字。

        【⏰ 班別代號（早 / 晚 / 整）平假日時間與休息換算表（請嚴格套用）】
        - **早（早班）**：
          * 平日（星期一～星期五）：`startTime: "10:30"`, `endTime: "14:30"`, `breakMin: 0`
          * 假日（星期六、星期日）：`startTime: "10:30"`, `endTime: "15:00"`, `breakMin: 0`
        - **晚（晚班）**：
          * 平日（星期一～星期五）：`startTime: "16:30"`, `endTime: "21:00"`, `breakMin: 0`
          * 假日（星期六、星期日）：`startTime: "17:00"`, `endTime: "21:00"`, `breakMin: 0`
        - **整（整天班）**：
          * 平日、假日皆相同：`startTime: "10:30"`, `endTime: "21:00"`, `breakMin: 120`（中間休息 2 小時 = 120 分鐘）
        - 其他補充規則：\(hintsText)
        - 使用者設定班別參考：\(stampRules)

        【📅 \(context.year) 年 \(context.month) 月 每日平假日對照表（共 \(dim) 天，\(context.month)/1 是星期\(firstWd)）】
        \(calendarLookupText)\(ocrAssistBlock)

        【🎯 真實班表辨識範例（Few-Shot 標準答案參考）】
        - 範例 A（2026 年 11 月班表，上半月已排 4 天）：
          * 11/4 (星期三・平日) 格內寫「4 弘鈞整 / UD休」 → `{"date":"2026-11-04","shiftType":"整","startTime":"10:30","endTime":"21:00","breakMin":120,"note":"弘鈞整"}`
          * 11/8 (星期日・假日) 格內寫「8 李弘整 / 語晚 UD休」 → `{"date":"2026-11-08","shiftType":"整","startTime":"10:30","endTime":"21:00","breakMin":120,"note":"李弘整"}`
          * 11/11 (星期三・平日) 格內寫「11 弘鈞整 / 雲休」 → `{"date":"2026-11-11","shiftType":"整","startTime":"10:30","endTime":"21:00","breakMin":120,"note":"弘鈞整"}`
          * 11/15 (星期日・假日) 格內寫「15 呈弘整 / 雲休 語晚」 → `{"date":"2026-11-15","shiftType":"整","startTime":"10:30","endTime":"21:00","breakMin":120,"note":"呈弘整"}`
        - 範例 B（2026 年 10 月班表，整月共 8 天；注意 10/16 寫的是「怡語晚」故無班）：
          * 10/7 (週三)「7 弘整」→ `10:30-21:00 (整, breakMin:120)`
          * 10/11 (週日)「11 李弘整」→ `10:30-21:00 (整, breakMin:120)`
          * 10/14 (週三)「14 弘鈞整」→ `10:30-21:00 (整, breakMin:120)`
          * 10/17 (週六・假日)「17 UD弘整」→ `10:30-21:00 (整, breakMin:120)`
          * 10/21 (週三)「21 弘整」→ `10:30-21:00 (整, breakMin:120)`
          * 10/24 (週六・假日)「24 呈鈞整 / 雲休 弘晚」→ `17:00-21:00 (晚, breakMin:0)`
          * 10/26 (週一)「26 弘李整」→ `10:30-21:00 (整, breakMin:120)`
          * 10/28 (週三)「28 鈞弘整」→ `10:30-21:00 (整, breakMin:120)`

        【輸出規則】
        - 只輸出純 JSON 陣列，不要任何說明文字、不要 markdown 程式碼框。
        - 每個元素格式：`{"date":"YYYY-MM-DD","shiftType":"整|晚|早","startTime":"HH:MM","endTime":"HH:MM","breakMin":120,"note":"格內原字樣"}`
        - 必須去除重複日期，並依日期（1號到月底）由小到大排序。
        """
    }
}
