import Foundation
import UIKit

/// JSON 寬鬆解析與手寫代號/時間正規化工具 (內建「早/晚/整」平假日時間與 2 小時休息自動校正器)
public enum ScheduleJSONParser {

    private struct RawShiftItem: Codable {
        var date: String?; var day: Int?; var shiftType: String?; var shift: String?; var type: String?
        var startTime: String?; var start: String?; var endTime: String?; var end: String?
        var breakMin: Int?; var note: String?
    }

    public static func resolveShiftCode(codeOrNote: String, dateKey: String) -> (startTime: String, endTime: String, breakMin: Int, shiftLabel: String)? {
        let wd = PayrollEngine.weekdayIndex(of: dateKey)
        let isWeekend = (wd == 0 || wd == 6)
        let text = codeOrNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("整") || text.contains("全") { return ("10:30", "21:00", 120, "整天班") }
        if text.contains("晚") { return (isWeekend ? "17:00" : "16:30", "21:00", 0, isWeekend ? "晚班(假日)" : "晚班(平日)") }
        if text.contains("早") { return ("10:30", isWeekend ? "15:00" : "14:30", 0, isWeekend ? "早班(假日)" : "早班(平日)") }
        return nil
    }

    public static func extractEmployeeShiftFromCellText(_ cellText: String, employeeName: String = "王凱弘") -> (shiftCode: String, matchedSegment: String)? {
        let short1 = String(employeeName.suffix(1)).isEmpty ? "弘" : String(employeeName.suffix(1))
        let normalized = cellText
            .replacingOccurrences(of: "34", with: "弘").replacingOccurrences(of: "弓ム", with: "弘")
            .replacingOccurrences(of: "弓厶", with: "弘").replacingOccurrences(of: "聖", with: "整")
            .replacingOccurrences(of: "壓", with: "整").replacingOccurrences(of: "堅", with: "整")
        let seps = CharacterSet(charactersIn: " \t\n\r/|｜,，、;；")
        let tokens = normalized.components(separatedBy: seps).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let regex = try? NSRegularExpression(pattern: #"([^整晚早休]*[整晚早休])"#) {
            for token in tokens {
                let ns = token as NSString
                for m in regex.matches(in: token, range: NSRange(location: 0, length: ns.length)) {
                    let seg = ns.substring(with: m.range)
                    guard seg.contains(short1) || seg.contains(employeeName), !seg.hasSuffix("休") else { continue }
                    if seg.hasSuffix("整") { return ("整", seg) }
                    if seg.hasSuffix("晚") { return ("晚", seg) }
                    if seg.hasSuffix("早") { return ("早", seg) }
                }
            }
        }
        if normalized.contains(short1) {
            if normalized.contains("整") { return ("整", normalized) }
            if normalized.contains("晚") { return ("晚", normalized) }
            if normalized.contains("早") { return ("早", normalized) }
        }
        return nil
    }

    public static func parseRows(from rawText: String, year: Int, month: Int) throws -> [ExtractedShiftRow] {
        let cleaned = extractJSONArrayString(from: rawText)
        let dim = PayrollEngine.daysInMonth(year: year, month: month)
        var byDate: [String: ExtractedShiftRow] = [:]

        if let data = cleaned.data(using: .utf8),
           let rawItems = try? JSONDecoder().decode([RawShiftItem].self, from: data) {
            for item in rawItems {
                let rawDate = item.date ?? (item.day != nil ? "\(item.day!)" : "")
                guard let dateKey = normalizeDate(rawDate, year: year, month: month, maxDay: dim) else { continue }

                let note = (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let codeHint = [item.shiftType, item.shift, item.type, note].compactMap { $0 }.joined(separator: " ")

                var st = normalizeHHMM(item.startTime ?? item.start ?? "")
                var et = normalizeHHMM(item.endTime ?? item.end ?? "")
                var brk = item.breakMin ?? -1
                var shiftLabel = ""

                if let resolved = resolveShiftCode(codeOrNote: codeHint, dateKey: dateKey) {
                    if !PayrollEngine.isValidHHMM(st) || !PayrollEngine.isValidHHMM(et) ||
                       st == "10:30" || st == "16:30" || st == "17:00" || st == "17:30" || st == "09:00" || st == "18:00" {
                        st = resolved.startTime
                        et = resolved.endTime
                    }
                    if brk < 0 {
                        brk = resolved.breakMin
                    }
                    shiftLabel = resolved.shiftLabel
                }

                guard PayrollEngine.isValidHHMM(st), PayrollEngine.isValidHHMM(et) else { continue }

                if st == "10:30" && et == "21:00" {
                    if brk <= 0 { brk = 120 }
                    if shiftLabel.isEmpty { shiftLabel = "整天班" }
                } else if brk < 0 {
                    brk = 0
                }

                byDate[dateKey] = ExtractedShiftRow(
                    date: dateKey,
                    startTime: st,
                    endTime: et,
                    breakMin: brk,
                    shiftLabel: shiftLabel,
                    note: note,
                    checked: true,
                    needsReview: note.contains("?")
                )
            }
        }

        if !byDate.isEmpty {
            return byDate.values.sorted { $0.date < $1.date }
        }

        // Fallback: 支援自然語言與簡寫代號輸入 (例如 "4整 8整 11整 15整" 或 "10/16 弘語晚")
        let shorthandRows = parseShorthandText(rawText, year: year, month: month, maxDay: dim)
        if !shorthandRows.isEmpty {
            return shorthandRows
        }

        throw NSError(domain: "ScheduleJSONParser", code: 400, userInfo: [NSLocalizedDescriptionKey: "無法從內容解析出班表，請確認格式或輸入如「4整 8整 11整 15整」"])
    }

    public static func parseShorthandText(_ text: String, year: Int, month: Int, maxDay: Int) -> [ExtractedShiftRow] {
        let pattern = #"(?:(\d{1,2})\s*[/月.\-]\s*)?(\d{1,2})\s*(?:日|號)?\s*([^\d\n,，、;；]{0,8}?[整晚早全])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var byDate: [String: ExtractedShiftRow] = [:]

        for m in matches {
            if m.range(at: 1).location != NSNotFound,
               let explicitMonth = Int(ns.substring(with: m.range(at: 1))),
               explicitMonth != month {
                continue
            }
            guard m.range(at: 2).location != NSNotFound,
                  let d = Int(ns.substring(with: m.range(at: 2))),
                  d >= 1 && d <= maxDay else { continue }
            let token = ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespaces)
            let dateKey = PayrollEngine.dateKey(year: year, month: month, day: d)
            if let resolved = resolveShiftCode(codeOrNote: token, dateKey: dateKey) {
                byDate[dateKey] = ExtractedShiftRow(
                    date: dateKey,
                    startTime: resolved.startTime,
                    endTime: resolved.endTime,
                    breakMin: resolved.breakMin,
                    shiftLabel: resolved.shiftLabel,
                    note: token,
                    checked: true,
                    needsReview: false
                )
            }
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
