import Foundation
import UIKit

/// JSON 寬鬆解析與手寫時間正規化工具 (支援多圖去重與按日期排序)
public enum ScheduleJSONParser {

    private struct RawShiftItem: Codable {
        var date: String?
        var day: Int?
        var startTime: String?
        var start: String?
        var endTime: String?
        var end: String?
        var note: String?
    }

    public static func parseRows(from rawText: String, year: Int, month: Int) throws -> [ExtractedShiftRow] {
        let cleaned = extractJSONArrayString(from: rawText)
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "ScheduleJSONParser", code: 400, userInfo: [NSLocalizedDescriptionKey: "AI 回傳內容無法轉為 UTF-8 資料"])
        }

        let rawItems = try JSONDecoder().decode([RawShiftItem].self, from: data)
        let dim = PayrollEngine.daysInMonth(year: year, month: month)
        var byDate: [String: ExtractedShiftRow] = [:]

        for item in rawItems {
            let rawDate = item.date ?? (item.day != nil ? "\(item.day!)" : "")
            guard let dateKey = normalizeDate(rawDate, year: year, month: month, maxDay: dim) else { continue }
            let st = normalizeHHMM(item.startTime ?? item.start ?? "")
            let et = normalizeHHMM(item.endTime ?? item.end ?? "")
            guard PayrollEngine.isValidHHMM(st), PayrollEngine.isValidHHMM(et) else { continue }
            let note = (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            byDate[dateKey] = ExtractedShiftRow(
                date: dateKey,
                startTime: st,
                endTime: et,
                note: note,
                checked: true,
                needsReview: note.contains("?")
            )
        }

        return byDate.values.sorted { $0.date < $1.date }
    }

    private static func extractJSONArrayString(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
        }
        if let startIdx = s.firstIndex(of: "["),
           let endIdx = s.lastIndex(of: "]"),
           startIdx <= endIdx {
            return String(s[startIdx...endIdx])
        }
        return s
    }

    public static func normalizeDate(_ raw: String, year: Int, month: Int, maxDay: Int) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if PayrollEngine.isValidDateKey(s) {
            return s
        }
        let nums = s.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        if nums.count == 3 {
            let d = nums[2]
            guard d >= 1 && d <= maxDay else { return nil }
            return PayrollEngine.dateKey(year: year, month: month, day: d)
        }
        if nums.count == 2 {
            let d = nums[1]
            guard d >= 1 && d <= maxDay else { return nil }
            return PayrollEngine.dateKey(year: year, month: month, day: d)
        }
        if nums.count == 1 {
            let d = nums[0]
            guard d >= 1 && d <= maxDay else { return nil }
            return PayrollEngine.dateKey(year: year, month: month, day: d)
        }
        return nil
    }

    public static func normalizeHHMM(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: ".", with: ":")
        if s.hasSuffix("半") {
            s = s.replacingOccurrences(of: "半", with: ":30")
        }
        let parts = s.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            let h = parts[0] == 24 ? 0 : parts[0]
            let m = parts[1]
            if (0...23).contains(h) && (0...59).contains(m) {
                return "\(PayrollEngine.pad2(h)):\(PayrollEngine.pad2(m))"
            }
        }
        if let hOnly = Int(s), (0...24).contains(hOnly) {
            return "\(PayrollEngine.pad2(hOnly == 24 ? 0 : hOnly)):00"
        }
        return s
    }

    public static func normalizeHandwrittenTimeRange(_ token: String) -> (String, String)? {
        let sepSet = CharacterSet(charactersIn: "-~～至")
        let parts = token.components(separatedBy: sepSet).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        var st = normalizeHHMM(parts[0])
        var et = normalizeHHMM(parts[1])
        guard PayrollEngine.isValidHHMM(st), PayrollEngine.isValidHHMM(et) else { return nil }

        let sHour = Int(st.prefix(2)) ?? 0
        let eHour = Int(et.prefix(2)) ?? 0
        if sHour <= 5 && eHour <= 12 {
            st = "\(PayrollEngine.pad2(sHour + 12)):\(st.suffix(2))"
        }
        if eHour > 0 && eHour < 12 && eHour <= (Int(st.prefix(2)) ?? 0) {
            et = "\(PayrollEngine.pad2(eHour + 12)):\(et.suffix(2))"
        }
        return (st, et)
    }
}
