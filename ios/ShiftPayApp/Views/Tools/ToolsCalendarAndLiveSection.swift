import SwiftUI

extension ToolsTabView {

    var calendarAndNotificationButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    let granted = await AlarmNotificationService.shared.requestPermission()
                    let nativeOK = await NativeWakeAlarmService.shared.requestAuthorization()
                    if granted || nativeOK {
                        let count = await AlarmNotificationService.shared.syncUpcomingNotifications(state: vm.state)
                        HapticsManager.shared.success()
                        if count > 0 {
                            vm.showToast("⏰ 已設定未來 \(count) 天的原生起床鬧鐘（每班 \(NativeWakeAlarmService.alarmsPerShift) 個）！", style: .success)
                        } else {
                            vm.showToast("⏰ 已啟用原生鬧鐘自動排程（目前近期尚無待響班表）", style: .success)
                        }
                    } else {
                        HapticsManager.shared.warning()
                        vm.showToast("請於「系統設定 → 打工薪水帳」開啟鬧鐘與通知權限", style: .warning)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "alarm.waves.left.and.right.fill")
                    Text("一鍵設定原生起床鬧鐘（每班 \(NativeWakeAlarmService.alarmsPerShift) 個）")
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
                        let nativeOK = await NativeWakeAlarmService.shared.requestAuthorization()
                        if granted || nativeOK {
                            _ = await AlarmNotificationService.shared.syncUpcomingNotifications(state: vm.state)
                            let native = await AlarmNotificationService.shared.sendImmediateTestNotification(state: vm.state)
                            HapticsManager.shared.success()
                            vm.showToast(native ? "⏰ 原生鬧鐘將於 5 秒後響起（可鎖定螢幕測試）！" : "🔔 已發送鬧鐘通知測試（1 秒後響起）", style: .success)
                        } else {
                            vm.showToast("請於系統設定開啟鬧鐘與通知權限", style: .warning)
                        }
                    }
                } label: {
                    Label("立即測試鬧鐘響鈴", systemImage: "bell.badge.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Button {
                    HapticsManager.shared.lightTap()
                    if let w = AlarmNotificationService.shared.openSystemClockApp(state: vm.state) {
                        vm.showToast("⏰ 已開啟系統時鐘（建議起床：\(w)）", style: .success)
                    }
                } label: {
                    Label("開啟系統時鐘", systemImage: "clock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color(hex: "#FFD60A"))
                }
            }

            HStack {
                Text("💡 蓋章或改班表時自動在背景同步更新原生鬧鐘")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Toggle("改班表自動同步鬧鐘", isOn: Binding(
                    get: { vm.state.settings.reminders.autoScheduleNotifications },
                    set: { val in
                        vm.state.settings.reminders.autoScheduleNotifications = val
                        vm.save()
                        vm.showToast(val ? "✅ 已開啟改班表自動同步原生鬧鐘" : "已關閉自動同步鬧鐘")
                    }
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
