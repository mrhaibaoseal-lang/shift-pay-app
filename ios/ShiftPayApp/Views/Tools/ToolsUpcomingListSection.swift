import SwiftUI

extension ToolsTabView {

    func widgetPreviewBox(payload: WidgetSyncPayload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("💰 \(payload.monthTitle)累積 (桌面原生 Widget 即時預覽)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(payload.bonusStatusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(payload.bonusOk ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(PayrollEngine.formatMoney(payload.totalPay))
                    .font(.system(size: 26, weight: .heavy))
                    .monospacedDigit()
                Spacer()
                Text("累計加班 \(payload.otMinutes) 分")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#FFD60A"))
            }
            if let nx = payload.nextShift {
                Text("🔥 下一班：\(nx.label) \(nx.time)（\(nx.name)）｜⏰ 起床 \(nx.wakeTime)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#64D2FF"))
            }

            Button {
                SharedStore.shared.saveState(vm.state, viewYear: vm.viewYear, viewMonth: vm.viewMonth)
                SharedStore.shared.reloadAllWidgets()
                HapticsManager.shared.success()
                vm.showToast("✅ 已同步刷新 iOS 原生桌面 Widget 小工具！", style: .success)
            } label: {
                Label("立即同步刷新原生桌面小工具", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }

    func upcoming7DaysCard(up: PayrollEngine.UpcomingScheduleSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📅 未來 7 天班表與原生起床鬧鐘一覽")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(vm.state.settings.reminders.wakeEnabled ? "🔔 鬧鐘自動連動中" : "🔕 鬧鐘已關閉")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(vm.state.settings.reminders.wakeEnabled ? Color(hex: "#30D158") : .white.opacity(0.4))
            }

            ForEach(up.days7) { item in
                HStack {
                    Text(item.offset == 0 ? "今天(\(item.weekdayText))" : (item.offset == 1 ? "明天(\(item.weekdayText))" : "\(item.month)/\(item.day)(\(item.weekdayText))"))
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .frame(width: 72, alignment: .leading)
                    if let sh = item.shift, item.isActiveShift {
                        Text(sh.name)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: sh.color), in: RoundedRectangle(cornerRadius: 5))
                        Text("\(sh.start)-\(sh.end)")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text("⏰ 起床 \(item.wakeTime ?? "")")
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: "#64D2FF"))
                    } else {
                        Text("休假 / 無排班")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
