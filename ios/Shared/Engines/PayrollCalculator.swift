import Foundation

extension PayrollEngine {

    public struct DayPayrollRow: Identifiable, Equatable, Sendable {
        public var id: String { key }
        public let key: String
        public let month: Int
        public let day: Int
        public let weekdayText: String
        public let shift: ShiftRecord
        public let normalMin: Int
        public let otMin: Int
        public let normalPay: Double
        public let otPay: Double

        public var totalDayPay: Double { normalPay + otPay }
    }

    public struct MonthComputation: Equatable, Sendable {
        public let year: Int
        public let month: Int
        public let days: [String]
        public let rows: [DayPayrollRow]
        public let normalMinTotal: Int
        public let otMinTotal: Int
        public let normalPay: Int
        public let otPay: Int
        public let bonus: Int
        public let bonusOk: Bool
        public let hasShift: Bool
        public let leaveCount: Int
        public let total: Int
        public let paydayHint: String
    }

    public static func computeMonth(state: ShiftPayState, year: Int, month: Int, now: Date = Date()) -> MonthComputation {
        let settings = state.settings
        let perMinWage = max(0, settings.hourlyWage) / 60.0
        let mult = max(0, settings.otMultiplier)
        let isDailyRound = (settings.roundingMode == .daily)
        let prefix = ymPrefix(year: year, month: month) + "-"

        let sortedKeys = state.shifts.keys.filter { $0.hasPrefix(prefix) }.sorted()
        var nMin = 0
        var oMin = 0
        var otDailySum = 0
        var leaveCount = 0
        var rows: [DayPayrollRow] = []

        for key in sortedKeys {
            guard let sh = state.shifts[key] else { continue }
            let nm = normalMinutes(of: sh)
            let om = overtimeMinutes(of: sh)
            nMin += nm
            oMin += om

            let otRaw = Double(om) * perMinWage * mult
            let otRounded = Int(otRaw.rounded())
            otDailySum += otRounded

            if sh.status == .leave {
                leaveCount += 1
            }

            let parts = key.split(separator: "-").compactMap { Int($0) }
            let mVal = parts.count >= 2 ? parts[1] : month
            let dVal = parts.count >= 3 ? parts[2] : 1
            let wd = ShiftPayConstants.weekDays[weekdayIndex(of: key)]

            rows.append(
                DayPayrollRow(
                    key: key,
                    month: mVal,
                    day: dVal,
                    weekdayText: wd,
                    shift: sh,
                    normalMin: nm,
                    otMin: om,
                    normalPay: Double(nm) * perMinWage,
                    otPay: isDailyRound ? Double(otRounded) : otRaw
                )
            )
        }

        let normalPay = Int((Double(nMin) * perMinWage).rounded())
        let otPay = isDailyRound ? otDailySum : Int((Double(oMin) * perMinWage * mult).rounded())
        let hasShift = !sortedKeys.isEmpty
        let bonusOk = hasShift && (leaveCount == 0)
        let bonus = bonusOk ? Int(max(0, settings.attendanceBonus).rounded()) : 0
        let total = normalPay + otPay + bonus

        let cal = Calendar(identifier: .gregorian)
        let realYear = cal.component(.year, from: now)
        let realMonth = cal.component(.month, from: now)
        let viewYmIdx = year * 12 + (month - 1)
        let realYmIdx = realYear * 12 + (realMonth - 1)
        let nextPayMonth = (month % 12) + 1

        let payTimeHint: String
        if viewYmIdx == realYmIdx {
            payTimeHint = "⏳ 本月上班累積中 ➔ 下月 (\(nextPayMonth)月) 發薪"
        } else if viewYmIdx == realYmIdx - 1 {
            payTimeHint = "✅ 上月工時 ➔ 本月 (\(realMonth)月) 發薪花用中"
        } else {
            payTimeHint = "⏳ 預計 \(nextPayMonth) 月發薪入帳"
        }

        return MonthComputation(
            year: year,
            month: month,
            days: sortedKeys,
            rows: rows,
            normalMinTotal: nMin,
            otMinTotal: oMin,
            normalPay: normalPay,
            otPay: otPay,
            bonus: bonus,
            bonusOk: bonusOk,
            hasShift: hasShift,
            leaveCount: leaveCount,
            total: total,
            paydayHint: payTimeHint
        )
    }
}
