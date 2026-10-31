import Foundation

public enum ICSExportGenerator {

    public static func generateMonthICS(state: ShiftPayState, year: Int, month: Int) -> String {
        let prefix = PayrollEngine.ymPrefix(year: year, month: month) + "-"
        let keys = state.shifts.keys.filter { key in
            guard key.hasPrefix(prefix), let sh = state.shifts[key] else { return false }
            return !PayrollEngine.isUnpaidLeave(sh)
        }.sorted()

        let rem = state.settings.reminders
        let prevMin = PayrollEngine.parseMinutes(rem.prevDayTime)
        let leadMin = max(5, rem.wakeLeadMin)

        let isoFormatter = ISO8601DateFormatter()
        let stampNow = isoFormatter.string(from: Date())
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")

        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//ShiftPay V3 iOS27//打工薪水帳//ZH",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:打工班表 (\(year)年\(month)月)"
        ]

        let cal = Calendar(identifier: .gregorian)
        for key in keys {
            guard let sh = state.shifts[key] else { continue }
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            let sParts = sh.start.split(separator: ":").compactMap { Int($0) }
            let eParts = sh.end.split(separator: ":").compactMap { Int($0) }
            guard sParts.count == 2, eParts.count == 2 else { continue }

            let startComp = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: sParts[0], minute: sParts[1])
            let endComp = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: eParts[0], minute: eParts[1])
            guard let startDt = cal.date(from: startComp),
                  var endDt = cal.date(from: endComp) else { continue }
            if endDt <= startDt {
                endDt = endDt.addingTimeInterval(86400)
            }

            let wakeStr = PayrollEngine.calculateWakeTime(shiftStart: sh.start, leadMinutes: leadMin)
            let startTotalMin = sParts[0] * 60 + sParts[1]
            let prevOffsetMin = max(1, (1440 - prevMin) + startTotalMin)

            lines.append(contentsOf: [
                "BEGIN:VEVENT",
                "UID:shiftpay-\(key)-\(sh.start.replacingOccurrences(of: ":", with: ""))@shiftpay.local",
                "DTSTAMP:\(stampNow)",
                "DTSTART:\(formatICSLocalDate(startDt, calendar: cal))",
                "DTEND:\(formatICSLocalDate(endDt, calendar: cal))",
                "SUMMARY:💼 打工：\(sh.name) (\(sh.start)-\(sh.end))",
                "DESCRIPTION:班別：\(sh.name)\\n表定時間：\(sh.start)-\(sh.end)\\n建議起床時間：\(wakeStr)\(sh.note.isEmpty ? "" : "\\n備註：\(sh.note)")"
            ])

            if rem.prevDayEnabled {
                lines.append(contentsOf: [
                    "BEGIN:VALARM",
                    "TRIGGER:-PT\(prevOffsetMin)M",
                    "ACTION:DISPLAY",
                    "DESCRIPTION:🌙 明天有班：\(sh.start) - \(sh.end)（\(sh.name)），記得設 \(wakeStr) 鬧鐘！",
                    "END:VALARM"
                ])
            }

            if rem.wakeEnabled {
                lines.append(contentsOf: [
                    "BEGIN:VALARM",
                    "TRIGGER:-PT\(leadMin)M",
                    "ACTION:DISPLAY",
                    "DESCRIPTION:☀️ 起床鬧鐘！今天 \(sh.start) - \(sh.end) 上班（\(sh.name)）",
                    "END:VALARM"
                ])
            }

            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }

    private static func formatICSLocalDate(_ date: Date, calendar: Calendar) -> String {
        let y = calendar.component(.year, from: date)
        let m = PayrollEngine.pad2(calendar.component(.month, from: date))
        let d = PayrollEngine.pad2(calendar.component(.day, from: date))
        let h = PayrollEngine.pad2(calendar.component(.hour, from: date))
        let min = PayrollEngine.pad2(calendar.component(.minute, from: date))
        return "\(y)\(m)\(d)T\(h)\(min)00"
    }
}
