import SwiftUI

extension DayEditorSheet {

    func timeAndBreakSection(sh: ShiftRecord) -> some View {
        let nm = PayrollEngine.normalMinutes(of: sh)
        let normalPay = Int((Double(nm) * (vm.state.settings.hourlyWage / 60.0)).rounded())
        let breakOptions = PayrollEngine.allBreakOptions(customBreaks: vm.state.settings.customBreaks, currentValue: sh.breakMin)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("表定時間與休息扣除").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text("正常工時 \(PayrollEngine.formatHours(nm))h · \(PayrollEngine.formatMoney(normalPay))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#64D2FF"))
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("上班 (HH:MM)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    TextField("09:00", text: Binding(
                        get: { sh.start },
                        set: { val in
                            let formatted = PayrollEngine.autoFormatTimeInput(val)
                            vm.state.shifts[dateKey]?.start = formatted
                            if PayrollEngine.isValidHHMM(formatted) {
                                vm.save()
                            }
                        }
                    ))
                    .submitLabel(.done)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("下班 (HH:MM)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    TextField("17:00", text: Binding(
                        get: { sh.end },
                        set: { val in
                            let formatted = PayrollEngine.autoFormatTimeInput(val)
                            vm.state.shifts[dateKey]?.end = formatted
                            if PayrollEngine.isValidHHMM(formatted) {
                                vm.save()
                            }
                        }
                    ))
                    .submitLabel(.done)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(breakOptions, id: \.self) { mins in
                    Button {
                        KeyboardDismissManager.dismiss()
                        vm.state.shifts[dateKey]?.breakMin = mins
                        HapticsManager.shared.lightTap()
                        vm.save()
                    } label: {
                        Text(PayrollEngine.formatBreakLabel(mins))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(sh.breakMin == mins ? Color(hex: "#0A84FF") : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("自訂休息分鐘 (如 45)", text: $customBreakInput)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .font(.system(size: 12))
                    .padding(9)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                Button("套用並設為常駐") {
                    KeyboardDismissManager.dismiss()
                    if let val = Int(customBreakInput.trimmingCharacters(in: .whitespacesAndNewlines)), val > 0 {
                        vm.addCustomBreakMinutes(val)
                        vm.state.shifts[dateKey]?.breakMin = val
                        vm.save()
                        customBreakInput = ""
                        HapticsManager.shared.lightTap()
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.blue.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color(hex: "#64D2FF"))
            }
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    func overtimeSection(sh: ShiftRecord) -> some View {
        let om = PayrollEngine.overtimeMinutes(of: sh)
        let otRaw = Double(om) * (vm.state.settings.hourlyWage / 60.0) * vm.state.settings.otMultiplier

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("當日分鐘級加班紀錄", systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#FFD60A"))
                Spacer()
                Text("加班費 +\(PayrollEngine.formatMoneySmart(otRaw))")
                    .font(.system(size: 13, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "#FFD60A"))
            }

            HStack(spacing: 6) {
                ForEach([10, 15, 30, 60], id: \.self) { addMin in
                    Button {
                        KeyboardDismissManager.dismiss()
                        vm.state.shifts[dateKey]?.otMin = max(0, sh.otMin + addMin)
                        HapticsManager.shared.lightTap()
                        vm.save()
                    } label: {
                        Text("+\(addMin)分")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color(hex: "#FFD60A"))
                    }
                }
                Button {
                    KeyboardDismissManager.dismiss()
                    vm.state.shifts[dateKey]?.otMin = 0
                    HapticsManager.shared.lightTap()
                    vm.save()
                } label: {
                    Text("歸零")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            HStack(spacing: 8) {
                Text("直接輸入加班")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                TextField("0", value: Binding(
                    get: { sh.otMin },
                    set: { newVal in
                        vm.state.shifts[dateKey]?.otMin = max(0, min(720, newVal))
                        vm.save()
                    }
                ), format: .number)
                .keyboardType(.numberPad)
                .submitLabel(.done)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .frame(width: 78)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                Text("分鐘")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Stepper(
                    "",
                    value: Binding(
                        get: { sh.otMin },
                        set: { newVal in
                            KeyboardDismissManager.dismiss()
                            vm.state.shifts[dateKey]?.otMin = max(0, newVal)
                            vm.save()
                        }
                    ),
                    in: 0...720,
                    step: 5
                )
                .labelsHidden()
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }
}
