import Foundation
import EventKit

/// EventKit 原生 iPhone 行事曆全自動同步服務 + .ics 雙鬧鐘匯出器
@MainActor
public final class CalendarSyncService {
    public static let shared = CalendarSyncService()
    private let store = EKEventStore()
    private let calendarTitle = "💰 打工班表"

    private init() {}

    public func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    /// 一鍵或背景自動將指定月份的班表直接寫入 iPhone 原生「行事曆」（含前一晚提醒 + 當日起床雙 EKAlarm）
    public func syncMonthToNativeCalendar(state: ShiftPayState, year: Int, month: Int) async throws -> Int {
        let granted = await requestAccess()
        guard granted else {
            throw NSError(domain: "CalendarSync", code: 403, userInfo: [NSLocalizedDescriptionKey: "尚未取得 iPhone 行事曆權限，請至「系統設定 → 隱私權與安全性 → 行事曆」開啟權限。"])
        }

        let targetCalendar = try findOrCreateShiftCalendar()
        let cal = Calendar(identifier: .gregorian)
        var startComp = DateComponents(year: year, month: month, day: 1, hour: 0, minute: 0)
        guard let monthStart = cal.date(from: startComp),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: 2), to: monthStart) else {
            return 0
        }

        // 先清除該月份在「💰 打工班表」專屬日曆內的舊事件，防止重複
        let predicate = store.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: [targetCalendar])
        let existingEvents = store.events(matching: predicate)
        for ev in existingEvents where ev.calendar == targetCalendar || (ev.notes?.contains("[ShiftPayV3]") == true) {
            try? store.remove(ev, span: .thisEvent, commit: false)
        }

        let prefix = PayrollEngine.ymPrefix(year: year, month: month) + "-"
        let keys = state.shifts.keys.filter { key in
            guard key.hasPrefix(prefix), let sh = state.shifts[key] else { return false }
            return !PayrollEngine.isUnpaidLeave(sh)
        }.sorted()

        let rem = state.settings.reminders
        let prevMin = PayrollEngine.parseMinutes(rem.prevDayTime)
        let leadMin = max(5, rem.wakeLeadMin)

        var writtenCount = 0
        for key in keys {
            guard let sh = state.shifts[key] else { continue }
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            let sParts = sh.start.split(separator: ":").compactMap { Int($0) }
            let eParts = sh.end.split(separator: ":").compactMap { Int($0) }
            guard sParts.count == 2, eParts.count == 2 else { continue }

            startComp = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: sParts[0], minute: sParts[1])
            var endComp = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: eParts[0], minute: eParts[1])
            guard let startDt = cal.date(from: startComp),
                  var endDt = cal.date(from: endComp) else { continue }
            if endDt <= startDt {
                endDt = endDt.addingTimeInterval(86400)
            }

            let wakeStr = PayrollEngine.calculateWakeTime(shiftStart: sh.start, leadMinutes: leadMin)
            let event = EKEvent(eventStore: store)
            event.calendar = targetCalendar
            event.title = "💼 打工：\(sh.name) (\(sh.start)-\(sh.end))"
            event.startDate = startDt
            event.endDate = endDt
            event.notes = "班別：\(sh.name)\n表定時間：\(sh.start)-\(sh.end)\n⏰ 建議起床時間：\(wakeStr)\(sh.note.isEmpty ? "" : "\n備註：\(sh.note)")\n[ShiftPayV3]"

            // EKAlarm 1: 前一天晚上提醒
            if rem.prevDayEnabled {
                let startTotalMin = sParts[0] * 60 + sParts[1]
                let prevOffsetMin = max(1, (1440 - prevMin) + startTotalMin)
                event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-prevOffsetMin * 60)))
            }

            // EKAlarm 2: 當日上班前 X 分鐘起床鬧鐘
            if rem.wakeEnabled {
                event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-leadMin * 60)))
            }

            try store.save(event, span: .thisEvent, commit: false)
            writtenCount += 1
        }

        try store.commit()
        return writtenCount
    }

    private func findOrCreateShiftCalendar() throws -> EKCalendar {
        let calendars = store.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle && $0.allowsContentModifications }) {
            return existing
        }
        let newCal = EKCalendar(for: .event, eventStore: store)
        newCal.title = calendarTitle
        if let source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local }) {
            newCal.source = source
            try store.saveCalendar(newCal, commit: true)
            return newCal
        }
        if let fallback = store.defaultCalendarForNewEvents {
            return fallback
        }
        throw NSError(domain: "CalendarSync", code: 500, userInfo: [NSLocalizedDescriptionKey: "找不到可寫入的行事曆來源"])
    }
}
