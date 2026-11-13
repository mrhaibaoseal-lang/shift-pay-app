import SwiftUI

struct ToolsTabView: View {
    @Bindable var vm: ShiftPayViewModel

    var body: some View {
        let up = vm.upcomingSummary

        ScrollView {
            VStack(spacing: 14) {
                heroWakeAlarmCard(up: up)
                alarmSettingsAndCalendarCard(up: up)
                liveActivityAndWidgetCard
                upcoming7DaysCard(up: up)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }

    private func heroWakeAlarmCard(up: PayrollEngine.UpcomingScheduleSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let tmr = up.tomorrowShift {
                    let wake = PayrollEngine.calculateWakeTime(shiftStart: tmr.start, leadMinutes: up.leadMinutes)
                    Text("☀️ 明日上班・建議起床鬧鐘")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#FFD60A"))
                    Text(wake)
                        .font(.system(size: 38, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("明日班表：\(tmr.name) \(tmr.start)-\(tmr.end)（提前 \(up.leadMinutes) 分鐘起床）")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                } else {
                    Text("🎉 明天沒有排班，可以睡到自然醒！")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "#30D158"))
                    if let nx = up.nextShift, let sh = nx.shift, let wake = nx.wakeTime {
                        Text("🔥 下一班：\(nx.month)/\(nx.day)(\(nx.weekdayText)) \(sh.name) \(sh.start)-\(sh.end) · 建議起床 \(wake)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("目前未來尚無排班紀錄")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: "alarm.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "#FFD60A"))
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(hex: "#291E12"), Color(hex: "#1C1C1E")], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    private func alarmSettingsAndCalendarCard(up: PayrollEngine.UpcomingScheduleSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { vm.state.settings.reminders.prevDayEnabled },
                set: { val in vm.state.settings.reminders.prevDayEnabled = val; vm.save() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🌙 上班前一晚提醒").font(.system(size: 14, weight: .bold))
                    Text("前一晚固定時間提醒隔天有班（預設 \(vm.state.settings.reminders.prevDayTime)）")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
            }

            Divider().background(.white.opacity(0.08))

            Toggle(isOn: Binding(
                get: { vm.state.settings.reminders.wakeEnabled },
                set: { val in vm.state.settings.reminders.wakeEnabled = val; vm.save() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("☀️ 上班當日起床鬧鐘").font(.system(size: 14, weight: .bold))
                    Text("依上班時間往回推算，連響 \(NativeWakeAlarmService.alarmsPerShift) 個系統鬧鐘（無視靜音）")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
            }

            HStack(spacing: 6) {
                ForEach([45, 60, 90, 120], id: \.self) { lead in
                    let active = (vm.state.settings.reminders.wakeLeadMin == lead)
                    Button {
                        KeyboardDismissManager.dismiss()
                        vm.state.settings.reminders.wakeLeadMin = lead
                        HapticsManager.shared.lightTap()
                        vm.save()
                        vm.showToast("已設定上班前 \(lead) 分鐘起床", style: .success)
                    } label: {
                        Text("\(lead) 分")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(active ? Color(hex: "#0A84FF") : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("自訂提前")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                TextField("90", value: $vm.state.settings.reminders.wakeLeadMin, format: .number)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .frame(width: 78)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: vm.state.settings.reminders.wakeLeadMin) { _, _ in vm.save() }
                Text("分鐘起床")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
            }

            HStack(spacing: 6) {
                Text("3 個鬧鐘間隔")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                ForEach([3, 5, 10], id: \.self) { gap in
                    let active = (vm.state.settings.reminders.wakeAlarmGapMin == gap)
                    Button {
                        vm.state.settings.reminders.wakeAlarmGapMin = gap
                        HapticsManager.shared.lightTap()
                        vm.save()
                        let times = NativeWakeAlarmService.ringOffsets(gapMinutes: gap).map { "+\($0)" }.joined(separator: " / ")
                        vm.showToast("起床鬧鐘：\(times) 分鐘各響一次", style: .success)
                    } label: {
                        Text("\(gap) 分")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(active ? Color(hex: "#FF9F0A") : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(active ? .black : .white)
                    }
                }
            }

            calendarAndNotificationButtons
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
