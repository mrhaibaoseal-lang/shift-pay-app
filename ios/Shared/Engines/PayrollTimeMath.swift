import Foundation

public enum PayrollEngine {

    public static func pad2(_ n: Int) -> String {
        String(format: "%02d", n)
    }

    public static func ymPrefix(year: Int, month: Int) -> String {
        "\(year)-\(pad2(month))"
    }

    public static func dateKey(year: Int, month: Int, day: Int) -> String {
        "\(year)-\(pad2(month))-\(pad2(day))"
    }

    public static func parseMinutes(_ hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    public static func spanMinutes(start: String, end: String) -> Int {
        var diff = parseMinutes(end) - parseMinutes(start)
        if diff <= 0 {
            diff += 1440
        }
        return diff
    }

    public static func isUnpaidLeave(_ shift: ShiftRecord) -> Bool {
        shift.status == .leave && shift.leaveType == .leave
    }

    public static func normalMinutes(of shift: ShiftRecord) -> Int {
        if isUnpaidLeave(shift) { return 0 }
        return max(0, spanMinutes(start: shift.start, end: shift.end) - max(0, shift.breakMin))
    }

    public static func overtimeMinutes(of shift: ShiftRecord) -> Int {
        if isUnpaidLeave(shift) { return 0 }
        return max(0, shift.otMin)
    }

    public static func stampWorkMinutes(_ stamp: ShiftStamp) -> Int {
        max(0, spanMinutes(start: stamp.start, end: stamp.end) - max(0, stamp.breakMin))
    }

    public static func formatHours(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60.0
        let rounded = (hours * 100).rounded() / 100
        if rounded == floor(rounded) {
            return String(Int(rounded))
        }
        return String(rounded)
    }

    public static func formatBreakLabel(_ minutes: Int) -> String {
        if minutes <= 0 { return "不扣除" }
        let h = Double(minutes) / 60.0
        if minutes % 30 == 0 {
            return "\(formatHours(minutes))h"
        }
        if h >= 1.0 && minutes % 15 == 0 {
            return "\(formatHours(minutes))h (\(minutes)分)"
        }
        return "\(minutes)分"
    }

    public static func allBreakOptions(customBreaks: [Int], currentValue: Int? = nil) -> [Int] {
        var set = Set(ShiftPayConstants.defaultBreakMins)
        for b in customBreaks where b > 0 && b <= 720 {
            set.insert(b)
        }
        if let cur = currentValue, cur >= 0 {
            set.insert(cur)
        }
        return set.sorted()
    }

    public static func formatMoney(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "$\(str)"
    }

    public static func formatMoneySmart(_ amount: Double) -> String {
        let roundedInt = Int(amount.rounded())
        if abs(amount - Double(roundedInt)) < 1e-6 {
            return formatMoney(roundedInt)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let str = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.1f", amount)
        return "$\(str)"
    }

    public static func calculateWakeTime(shiftStart: String, leadMinutes: Int) -> String {
        let startMin = parseMinutes(shiftStart)
        let wakeMin = ((startMin - max(0, leadMinutes)) % 1440 + 1440) % 1440
        let h = wakeMin / 60
        let m = wakeMin % 60
        return "\(pad2(h)):\(pad2(m))"
    }

    public static func weekdayIndex(of dateKey: String) -> Int {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return 0 }
        var comp = DateComponents()
        comp.year = parts[0]
        comp.month = parts[1]
        comp.day = parts[2]
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comp) else { return 0 }
        return cal.component(.weekday, from: date) - 1
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comp),
              let range = cal.range(of: .day, in: .month, for: date) else {
            return 30
        }
        return range.count
    }

    public static func isValidHHMM(_ text: String) -> Bool {
        let pattern = #"^(?:[01]\d|2[0-3]):[0-5]\d$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    public static func autoFormatTimeInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = trimmed.filter(\.isNumber)
        if digitsOnly.count == 4 && !trimmed.contains(":") {
            let h = String(digitsOnly.prefix(2))
            let m = String(digitsOnly.suffix(2))
            let candidate = "\(h):\(m)"
            if isValidHHMM(candidate) {
                return candidate
            }
        }
        return trimmed
    }

    public static func isValidDateKey(_ text: String) -> Bool {
        let pattern = #"^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
