import SwiftUI

extension ToolsTabView {

    var calendarAndNotificationButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    do {
                        let count = try await CalendarSyncService.shared.syncMonthToNativeCalendar(
                            state: vm.state,
                            year: vm.viewYear,
                            month: vm.viewMonth
                        )
                        HapticsManager.shared.success()
                        vm.showToast("📲 已直接寫入 \(count) 天班表與雙鬧鐘至 iPhone 原生行事曆！", style: .success)
                    } catch {
                        HapticsManager.shared.warning()
                        vm.showToast(error.localizedDescription, style: .error)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text("一鍵直接同步 \(vm.viewMonth) 月至 iPhone 原生行事曆鬧鐘 (EventKit)")
                }
                .font(.system(size: 13, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(hex: "#FFD60A"), Color(hex: "#FF9F0A")], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(.black)
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        let granted = await AlarmNotificationService.shared.requestPermission()
                        if granted {
                            let count = await AlarmNotificationService.shared.syncUpcomingNotifications(state: vm.state)
                            await AlarmNotificationService.shared.sendImmediateTestNotification(state: vm.state)
                            vm.showToast("🔔 已排程 \(count) 筆高優先級起床通知並發送測試！", style: .success)
                        } else {
                            vm.showToast("請於系統設定開啟通知權限", style: .warning)
                        }
                    }
                } label: {
                    Label("啟用並測試系統鬧鐘通知", systemImage: "bell.badge.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Toggle("改班表自動同步行事曆", isOn: Binding(
                    get: { vm.state.settings.reminders.autoSyncCalendar },
                    set: { val in vm.state.settings.reminders.autoSyncCalendar = val; vm.save() }
                ))
                .font(.system(size: 11, weight: .semibold))
                .toggleStyle(.button)
                .tint(Color(hex: "#30D158"))
            }
        }
    }

    var liveActivityAndWidgetCard: some View {
        let payload = SharedStore.shared.loadWidgetPayload()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("動態島即時跳錶 & 原生桌面 Widget", systemImage: "platter.filled.top.iphone")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Feather Keychain 已連線")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.2), in: Capsule())
                    .foregroundStyle(Color(hex: "#30D158"))
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        do {
                            try await LiveActivityManager.shared.startOrUpdateShiftLiveActivity(
                                state: vm.state,
                                viewYear: vm.viewYear,
                                viewMonth: vm.viewMonth
                            )
                            HapticsManager.shared.success()
                            vm.showToast("🏝️ 已啟動動態島與鎖定畫面即時薪資跳錶！", style: .success)
                        } catch {
                            vm.showToast(error.localizedDescription, style: .warning)
                        }
                    }
                } label: {
                    Label("啟動動態島即時跳錶", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(hex: "#5E5CE6"), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Button {
                    Task {
                        await LiveActivityManager.shared.stopAllLiveActivities()
                        vm.showToast("已關閉動態島即時動態")
                    }
                } label: {
                    Text("關閉動態島")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }

            widgetPreviewBox(payload: payload)
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
