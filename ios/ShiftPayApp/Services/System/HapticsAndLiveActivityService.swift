import Foundation
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// iOS 原生觸覺回饋 (CoreHaptics / UIImpactFeedbackGenerator) 與動態島 Live Activity 薪資跳錶服務
@MainActor
public final class HapticsManager {
    public static let shared = HapticsManager()
    private init() {}

    public func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func stampImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()
    private init() {}

    public var isLiveActivityRunning: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 17.0, *) {
            return !Activity<ShiftLiveActivityAttributes>.activities.isEmpty
        }
        #endif
        return false
    }

    /// 啟動或更新「動態島 & 鎖定畫面：上班即時薪資跳錶」
    public func startOrUpdateShiftLiveActivity(state: ShiftPayState, viewYear: Int, viewMonth: Int) async throws {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(domain: "LiveActivity", code: 403, userInfo: [NSLocalizedDescriptionKey: "系統設定尚未開啟「即時動態 (Live Activities)」權限"])
        }

        let comp = PayrollEngine.computeMonth(state: state, year: viewYear, month: viewMonth)
        let up = PayrollEngine.upcomingSchedule(state: state)

        let shiftName: String
        let timeRange: String
        let currentShiftPay: Int
        let progress: Double
        let statusHint: String

        if let nx = up.nextShift, let sh = nx.shift {
            shiftName = sh.name
            timeRange = "\(sh.start)-\(sh.end)"
            let workMin = PayrollEngine.normalMinutes(of: sh)
            let estShiftPay = Int((Double(workMin) * (state.settings.hourlyWage / 60.0)).rounded())
            currentShiftPay = estShiftPay
            progress = nx.offset == 0 ? 0.65 : 0.15
            statusHint = nx.offset == 0
                ? "🔥 今日班表進行中｜預估本班 +\(PayrollEngine.formatMoney(estShiftPay))"
                : "⏰ 下一班 \(nx.month)/\(nx.day)｜起床鬧鐘 \(nx.wakeTime ?? "07:30")"
        } else {
            shiftName = "本月累積 \(comp.days.count) 天"
            timeRange = "\(viewMonth)月總覽"
            currentShiftPay = comp.total
            progress = 1.0
            statusHint = comp.bonusOk ? "🔥 全勤達成｜累積加班 \(comp.otMinTotal)m" : "累計加班 \(comp.otMinTotal)m"
        }

        let contentState = ShiftLiveActivityAttributes.ContentState(
            shiftName: shiftName,
            timeRange: timeRange,
            currentShiftPay: currentShiftPay,
            monthTotalPay: comp.total,
            otMinutes: comp.otMinTotal,
            progress: progress,
            statusHint: statusHint
        )

        let attributes = ShiftLiveActivityAttributes(
            employeeName: state.settings.myName,
            hourlyWage: Int(state.settings.hourlyWage)
        )

        if let existing = Activity<ShiftLiveActivityAttributes>.activities.first {
            await existing.update(ActivityContent(state: contentState, staleDate: nil))
        } else {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil),
                pushType: nil
            )
        }
        #endif
    }

    public func stopAllLiveActivities() async {
        #if canImport(ActivityKit)
        for activity in Activity<ShiftLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        #endif
    }
}
