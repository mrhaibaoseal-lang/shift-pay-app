import Foundation
import UserNotifications

/// 原生高優先級起床鬧鐘與前一晚提醒排程服務 + .ics 雙 VALARM 產生器
@MainActor
public final class AlarmNotificationService {
    public static let shared = AlarmNotificationService()

    private init() {}

    public func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// 自動排程未來 14 天的「前一晚提醒」與「當日起床鬧鐘 (Time-Sensitive 高優先級突破專注模式)」
    public func syncUpcomingNotifications(state: ShiftPayState) async -> Int {
        let center = UNUserNotificationCenter.current()
        let status = await checkAuthorizationStatus()
        guard status == .authorized || status == .provisional else { return 0 }

        center.removeAllPendingNotificationRequests()

        let rem = state.settings.reminders
        guard rem.prevDayEnabled || rem.wakeEnabled else { return 0 }

        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let leadMin = max(5, rem.wakeLeadMin)
        let prevParts = rem.prevDayTime.split(separator: ":").compactMap { Int($0) }
        let prevHour = prevParts.count == 2 ? prevParts[0] : 21
        let prevMinute = prevParts.count == 2 ? prevParts[1] : 0

        var scheduledCount = 0

        for offset in 0..<14 {
            guard let shiftDate = cal.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let y = cal.component(.year, from: shiftDate)
            let m = cal.component(.month, from: shiftDate)
            let d = cal.component(.day, from: shiftDate)
            let key = PayrollEngine.dateKey(year: y, month: m, day: d)

            guard let sh = state.shifts[key], !PayrollEngine.isUnpaidLeave(sh) else { continue }
            let wakeHHMM = PayrollEngine.calculateWakeTime(shiftStart: sh.start, leadMinutes: leadMin)

            // 1. 前一晚提醒
            if rem.prevDayEnabled,
               let prevDayDate = cal.date(byAdding: .day, value: -1, to: shiftDate) {
                var prevComp = cal.dateComponents([.year, .month, .day], from: prevDayDate)
                prevComp.hour = prevHour
                prevComp.minute = prevMinute
                if let fireDate = cal.date(from: prevComp), fireDate > now {
                    let content = UNMutableNotificationContent()
                    content.title = "🌙 明天有班提醒 (\(m)/\(d))"
                    content.body = "明日班表：\(sh.name) \(sh.start)-\(sh.end)｜建議 \(wakeHHMM) 起床（上班前 \(leadMin) 分鐘）"
                    content.sound = .default
                    content.interruptionLevel = .timeSensitive

                    let req = UNNotificationRequest(
                        identifier: "shiftpay.prev.\(key)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: prevComp, repeats: false)
                    )
                    try? await center.add(req)
                    scheduledCount += 1
                }
            }

            // 2. 當日起床鬧鐘
            if rem.wakeEnabled {
                let wParts = wakeHHMM.split(separator: ":").compactMap { Int($0) }
                if wParts.count == 2 {
                    var wakeComp = cal.dateComponents([.year, .month, .day], from: shiftDate)
                    wakeComp.hour = wParts[0]
                    wakeComp.minute = wParts[1]
                    if let fireDate = cal.date(from: wakeComp), fireDate > now {
                        let content = UNMutableNotificationContent()
                        content.title = "☀️ 上班起床鬧鐘！(\(wakeHHMM))"
                        content.body = "今日班表：\(sh.name) \(sh.start)-\(sh.end)，準備起床出發囉！"
                        content.sound = .defaultCritical
                        content.interruptionLevel = .timeSensitive

                        let req = UNNotificationRequest(
                            identifier: "shiftpay.wake.\(key)",
                            content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: wakeComp, repeats: false)
                        )
                        try? await center.add(req)
                        scheduledCount += 1
                    }
                }
            }
        }
        return scheduledCount
    }

    public func sendImmediateTestNotification(state: ShiftPayState) async {
        let up = PayrollEngine.upcomingSchedule(state: state)
        let body: String
        if let tmr = up.tomorrowShift {
            let wake = PayrollEngine.calculateWakeTime(shiftStart: tmr.start, leadMinutes: up.leadMinutes)
            body = "明天有班：\(tmr.start)-\(tmr.end)（\(tmr.name)）｜建議起床鬧鐘：\(wake)"
        } else if let nx = up.nextShift, let sh = nx.shift, let wake = nx.wakeTime {
            body = "下一班 \(nx.month)/\(nx.day) \(sh.start)-\(sh.end)（\(sh.name)）｜建議起床：\(wake)"
        } else {
            body = "目前尚無近期排班，iOS 原生高優先級鬧鐘通知運作正常！"
        }

        let content = UNMutableNotificationContent()
        content.title = "💰 打工薪水帳・原生鬧鐘測試"
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let req = UNNotificationRequest(identifier: "shiftpay.test.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }
}
