import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
public final class ShiftPayViewModel {
    public var state: ShiftPayState
    public var viewYear: Int
    public var viewMonth: Int
    public var activeTab: AppTab = .schedule
    public var activeStampId: String? = nil

    // Sheet 控制狀態
    public var editingDateKey: String? = nil
    public var showStampManager: Bool = false
    public var showPhotoImportSheet: Bool = false
    public var showStatementPreviewSheet: Bool = false

    // Toast 訊息提示
    public var toastMessage: String? = nil
    public var toastStyle: ToastStyle = .normal

    public enum AppTab: String, CaseIterable {
        case schedule = "schedule"
        case bill     = "bill"
        case tools    = "tools"
        case settings = "settings"
    }

    public enum ToastStyle {
        case normal, success, warning, error
    }

    public init() {
        let loaded = SharedStore.shared.loadState()
        self.state = loaded
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        self.viewYear = cal.component(.year, from: now)
        self.viewMonth = cal.component(.month, from: now)
    }

    public var currentMonthComputation: PayrollEngine.MonthComputation {
        PayrollEngine.computeMonth(state: state, year: viewYear, month: viewMonth)
    }

    public var upcomingSummary: PayrollEngine.UpcomingScheduleSummary {
        PayrollEngine.upcomingSchedule(state: state)
    }

    public func save() {
        SharedStore.shared.saveState(state, viewYear: viewYear, viewMonth: viewMonth)
        if state.settings.reminders.autoScheduleNotifications {
            Task {
                _ = await AlarmNotificationService.shared.syncUpcomingNotifications(state: state)
            }
        }
    }

    public func showToast(_ text: String, style: ToastStyle = .normal) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.toastMessage = text
            self.toastStyle = style
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if self.toastMessage == text {
                withAnimation {
                    self.toastMessage = nil
                }
            }
        }
    }

    // MARK: - 月份切換
    public func changeMonth(delta: Int) {
        var m = viewMonth + delta
        var y = viewYear
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            viewYear = y
            viewMonth = m
        }
        HapticsManager.shared.lightTap()
    }

    public func jumpToToday() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            viewYear = cal.component(.year, from: now)
            viewMonth = cal.component(.month, from: now)
        }
        HapticsManager.shared.lightTap()
        showToast("已回到本月")
    }

    // MARK: - 蓋章與點擊日期邏輯
    public func handleCalendarDayTap(dateKey: String) {
        if let stampId = activeStampId {
            applyStamp(dateKey: dateKey, stampId: stampId)
        } else {
            HapticsManager.shared.lightTap()
            editingDateKey = dateKey
        }
    }

    public func applyStamp(dateKey: String, stampId: String) {
        if stampId == "clear" {
            guard state.shifts[dateKey] != nil else { return }
            state.shifts.removeValue(forKey: dateKey)
            HapticsManager.shared.lightTap()
            save()
            return
        }

        guard let st = state.stamps.first(where: { $0.id == stampId }) else { return }
        let prev = state.shifts[dateKey]
        state.shifts[dateKey] = ShiftRecord(
            name: st.name,
            color: st.color,
            start: st.start,
            end: st.end,
            breakMin: st.breakMin,
            stampId: st.id,
            otMin: prev?.otMin ?? 0,
            status: prev?.status ?? .normal,
            leaveType: prev?.leaveType ?? .late,
            note: prev?.note ?? ""
        )
        HapticsManager.shared.stampImpact()
        save()
    }

    public func addCustomBreakMinutes(_ mins: Int) {
        let clamped = max(1, min(720, mins))
        if !ShiftPayConstants.defaultBreakMins.contains(clamped) && !state.settings.customBreaks.contains(clamped) {
            state.settings.customBreaks.append(clamped)
            state.settings.customBreaks.sort()
            save()
        }
    }
}
