import Foundation
import UserNotifications
import UIKit

/// 原生高優先級起床連環鬧鐘與前一晚提醒排程服務
@MainActor
public final class AlarmNotificationService: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = AlarmNotificationService()

    public static let wakeCategoryId = "SHIFTPAY_WAKE_ALARM"
    public static let stopActionId = "STOP_WAKE_ALARM"
    public static let snoozeActionId = "SNOOZE_WAKE_ALARM"

    private override init() {
        super.init()
        configureNotificationCategories()
    }

    public func configureNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let stopAction = UNNotificationAction(
            identifier: Self.stopActionId,
            title: "✋ 我已起床（停止後續連響）",
            options: [.destructive]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionId,
            title: "💤 貪睡 5 分鐘後再響",
            options: []
        )
        let wakeCategory = UNNotificationCategory(
            identifier: Self.wakeCategoryId,
            actions: [stopAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([wakeCategory])
    }

    public func requestPermission() async -> Bool {
        configureNotificationCategories()
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

    /// 自動排程未來 14 天的「前一晚提醒」與「當日起床連環鬧鐘 (Time-Sensitive 高優先級突破專注模式)」
    public func syncUpcomingNotifications(state: ShiftPayState) async -> Int {
        configureNotificationCategories()
        let center = UNUserNotificationCenter.current()
        var status = await checkAuthorizationStatus()
        if status == .notDetermined {
            _ = await requestPermission()
            status = await checkAuthorizationStatus()
        }
        let notificationsAllowed = status == .authorized || status == .provisional

        let rem = state.settings.reminders
        // iOS 26+：起床鬧鐘改用 AlarmKit 原生系統鬧鐘（無視靜音／專注模式、全螢幕響鈴）
        let useNativeAlarms = await NativeWakeAlarmService.shared.requestAuthorization()
        var nativeRequests: [NativeWakeAlarmService.WakeAlarmRequest] = []
        let offsets = NativeWakeAlarmService.ringOffsets(gapMinutes: rem.wakeAlarmGapMin)

        if notificationsAllowed {
            center.removeAllPendingNotificationRequests()
        }
        guard rem.prevDayEnabled || rem.wakeEnabled else {
            if useNativeAlarms { await NativeWakeAlarmService.shared.replaceAll(with: []) }
            return 0
        }
        guard notificationsAllowed || useNativeAlarms else { return 0 }

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
            if rem.prevDayEnabled, notificationsAllowed,
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

            // 2. 當日起床鬧鐘 ×3（T、T+gap、T+2·gap）
            if rem.wakeEnabled {
                let wParts = wakeHHMM.split(separator: ":").compactMap { Int($0) }
                if wParts.count == 2 {
                    var wakeComp = cal.dateComponents([.year, .month, .day], from: shiftDate)
                    wakeComp.hour = wParts[0]
                    wakeComp.minute = wParts[1]
                    if let baseWakeDate = cal.date(from: wakeComp) {
                        var addedWake = false
                        for (idx, addMin) in offsets.enumerated() {
                            guard let ringDate = cal.date(byAdding: .minute, value: addMin, to: baseWakeDate),
                                  ringDate > now else { continue }
                            let title = idx == 0
                                ? "⏰ 起床！\(sh.name) \(sh.start) 上班"
                                : "🚨 第 \(idx + 1)/\(offsets.count) 個起床鬧鐘・\(sh.name) \(sh.start)"
                            if useNativeAlarms {
                                nativeRequests.append(.init(fireDate: ringDate, title: title))
                                addedWake = true
                                continue
                            }
                            guard notificationsAllowed else { continue }
                            let rComp = cal.dateComponents([.year, .month, .day, .hour, .minute], from: ringDate)
                            let content = UNMutableNotificationContent()
                            content.title = title
                            content.body = "今日班表 \(sh.start)-\(sh.end)，準備起床出發！（長按可點「我已起床」停止後續連響）"
                            content.sound = .defaultCritical
                            content.interruptionLevel = .timeSensitive
                            content.categoryIdentifier = Self.wakeCategoryId
                            content.userInfo = ["dateKey": key]

                            let req = UNNotificationRequest(
                                identifier: "shiftpay.wake.\(key).\(addMin)",
                                content: content,
                                trigger: UNCalendarNotificationTrigger(dateMatching: rComp, repeats: false)
                            )
                            try? await center.add(req)
                            addedWake = true
                        }
                        if addedWake { scheduledCount += 1 }
                    }
                }
            }
        }

        if useNativeAlarms {
            await NativeWakeAlarmService.shared.replaceAll(with: nativeRequests)
        }
        return scheduledCount
    }

    @discardableResult
    public func sendImmediateTestNotification(state: ShiftPayState) async -> Bool {
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

        // iOS 26+：直接排一個 5 秒後響起的原生系統鬧鐘
        if await NativeWakeAlarmService.shared.requestAuthorization(),
           await NativeWakeAlarmService.shared.schedule(fireDate: Date().addingTimeInterval(5), title: "⏰ 打工薪水帳・起床鬧鐘測試") {
            return true
        }

        let content = UNMutableNotificationContent()
        content.title = "⏰ 打工薪水帳・原生起床鬧鐘測試"
        content.body = body
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.wakeCategoryId

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.2, repeats: false)
        let req = UNNotificationRequest(identifier: "shiftpay.test.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
        return false
    }

    public func openSystemClockApp(state: ShiftPayState? = nil) -> String? {
        var nextWake: String? = nil
        if let st = state {
            let up = PayrollEngine.upcomingSchedule(state: st)
            if let tmr = up.tomorrowShift {
                nextWake = PayrollEngine.calculateWakeTime(shiftStart: tmr.start, leadMinutes: up.leadMinutes)
            } else if let nx = up.nextShift?.wakeTime {
                nextWake = nx
            }
            if let w = nextWake {
                UIPasteboard.general.string = w
            }
        }
        if let url = URL(string: "clock-alarm://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: "clock-worldclock://"), UIApplication.shared.canOpenURL(fallback) {
            UIApplication.shared.open(fallback)
        }
        return nextWake
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let dateKey = userInfo["dateKey"] as? String ?? ""

        if response.actionIdentifier == Self.stopActionId, !dateKey.isEmpty {
            let ids = (0..<NativeWakeAlarmService.alarmsPerShift).flatMap { idx in
                (1...30).map { gap in "shiftpay.wake.\(dateKey).\(idx * gap)" }
            }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        } else if response.actionIdentifier == Self.snoozeActionId {
            let content = UNMutableNotificationContent()
            content.title = "⏰ 貪睡 5 分鐘時間到！該起床上班囉"
            content.body = response.notification.request.content.body
            content.sound = .defaultCritical
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = Self.wakeCategoryId
            content.userInfo = userInfo

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
            let req = UNNotificationRequest(identifier: "shiftpay.snooze.\(UUID().uuidString)", content: content, trigger: trigger)
            center.add(req)
        }
        completionHandler()
    }
}
