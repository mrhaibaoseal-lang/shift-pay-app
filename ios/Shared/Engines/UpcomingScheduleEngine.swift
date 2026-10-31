import Foundation

extension PayrollEngine {

    public struct UpcomingDayItem: Identifiable, Equatable, Sendable {
        public var id: String { key }
        public let offset: Int
        public let key: String
        public let month: Int
        public let day: Int
        public let weekdayText: String
        public let shift: ShiftRecord?
        public let wakeTime: String?

        public var isActiveShift: Bool {
            guard let shift else { return false }
            return !PayrollEngine.isUnpaidLeave(shift)
        }
    }

    public struct UpcomingScheduleSummary: Equatable, Sendable {
        public let reminders: ReminderSettings
        public let leadMinutes: Int
        public let todayKey: String
        public let tomorrowKey: String
        public let tomorrowShift: ShiftRecord?
        public let days7: [UpcomingDayItem]
        public let nextShift: UpcomingDayItem?
    }

    public static func upcomingSchedule(state: ShiftPayState, now: Date = Date()) -> UpcomingScheduleSummary {
        let cal = Calendar(identifier: .gregorian)
        let rem = state.settings.reminders
        let lead = max(5, rem.wakeLeadMin)
        let startOfToday = cal.startOfDay(for: now)
        var days7: [UpcomingDayItem] = []

        for i in 0..<7 {
            guard let dt = cal.date(byAdding: .day, value: i, to: startOfToday) else { continue }
            let y = cal.component(.year, from: dt)
            let m = cal.component(.month, from: dt)
            let d = cal.component(.day, from: dt)
            let wd = ShiftPayConstants.weekDays[cal.component(.weekday, from: dt) - 1]
            let key = dateKey(year: y, month: m, day: d)
            let sh = state.shifts[key]
            let active = (sh != nil && !isUnpaidLeave(sh!))
            let wake = active ? calculateWakeTime(shiftStart: sh!.start, leadMinutes: lead) : nil
            days7.append(UpcomingDayItem(offset: i, key: key, month: m, day: d, weekdayText: wd, shift: sh, wakeTime: wake))
        }

        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        var nextShift: UpcomingDayItem? = nil

        for i in 0..<30 {
            guard let dt = cal.date(byAdding: .day, value: i, to: startOfToday) else { continue }
            let y = cal.component(.year, from: dt)
            let m = cal.component(.month, from: dt)
            let d = cal.component(.day, from: dt)
            let wd = ShiftPayConstants.weekDays[cal.component(.weekday, from: dt) - 1]
            let key = dateKey(year: y, month: m, day: d)
            guard let sh = state.shifts[key], !isUnpaidLeave(sh) else { continue }
            if i == 0 && parseMinutes(sh.end) <= nowMinutes && parseMinutes(sh.end) > parseMinutes(sh.start) {
                continue
            }
            nextShift = UpcomingDayItem(offset: i, key: key, month: m, day: d, weekdayText: wd, shift: sh, wakeTime: calculateWakeTime(shiftStart: sh.start, leadMinutes: lead))
            break
        }

        let todayKey = days7.first?.key ?? ""
        let tomorrowItem = days7.count > 1 ? days7[1] : nil
        let tmrShift = (tomorrowItem?.isActiveShift == true) ? tomorrowItem?.shift : nil

        return UpcomingScheduleSummary(
            reminders: rem,
            leadMinutes: lead,
            todayKey: todayKey,
            tomorrowKey: tomorrowItem?.key ?? "",
            tomorrowShift: tmrShift,
            days7: days7,
            nextShift: nextShift
        )
    }

    public static func buildWidgetPayload(state: ShiftPayState, viewYear: Int? = nil, viewMonth: Int? = nil, now: Date = Date()) -> WidgetSyncPayload {
        let cal = Calendar(identifier: .gregorian)
        let y = viewYear ?? cal.component(.year, from: now)
        let m = viewMonth ?? cal.component(.month, from: now)
        let comp = computeMonth(state: state, year: y, month: m, now: now)
        let up = upcomingSchedule(state: state, now: now)

        let bonusText = !comp.hasShift ? "尚未排班" : (comp.bonusOk ? "🔥全勤達成" : "❌已扣全勤")
        var nextInfo: WidgetNextShiftInfo? = nil
        if let nx = up.nextShift, let sh = nx.shift, let wake = nx.wakeTime {
            let dayLabel = nx.offset == 0 ? "今天" : (nx.offset == 1 ? "明天" : "\(nx.month)/\(nx.day)(\(nx.weekdayText))")
            nextInfo = WidgetNextShiftInfo(date: nx.key, label: dayLabel, name: sh.name, color: sh.color, time: "\(sh.start)-\(sh.end)", wakeTime: wake)
        }

        return WidgetSyncPayload(
            month: ymPrefix(year: y, month: m),
            monthTitle: "\(m)月",
            paydayHint: comp.paydayHint,
            totalPay: comp.total,
            normalPay: comp.normalPay,
            otPay: comp.otPay,
            bonusPay: comp.bonus,
            bonusOk: comp.bonusOk,
            bonusStatusText: bonusText,
            normalHours: formatHours(comp.normalMinTotal),
            otMinutes: comp.otMinTotal,
            shiftDays: comp.days.count,
            nextShift: nextInfo
        )
    }
}
