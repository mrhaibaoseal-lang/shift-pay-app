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

            HStack(spacing: 8) {
                Button {
                    if let data = try? JSONEncoder().encode(payload),
                       let jsonStr = String(data: data, encoding: .utf8) {
                        UIPasteboard.general.string = jsonStr
                        HapticsManager.shared.success()
                        vm.showToast("✅ 已複製班表 JSON 數據（支援 Scriptable 小工具秒同步）！", style: .success)
                    }
                } label: {
                    Label("一鍵複製小工具 JSON", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }

                Button {
                    let ics = ICSExportGenerator.generateMonthICS(state: vm.state, year: vm.viewYear, month: vm.viewMonth)
                    UIPasteboard.general.string = ics
                    HapticsManager.shared.success()
                    vm.showToast("📋 已複製 .ics 行事曆內容至剪貼簿", style: .success)
                } label: {
                    Label("備用複製 .ics", systemImage: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }

    func upcoming7DaysCard(up: PayrollEngine.UpcomingScheduleSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📅 未來 7 天班表與起床鬧鐘一覽")
                .font(.system(size: 14, weight: .bold))

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
