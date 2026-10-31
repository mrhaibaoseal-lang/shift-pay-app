import SwiftUI

struct SettingsTabView: View {
    @Bindable var vm: ShiftPayViewModel
    @State var showImportJSONSheet = false
    @State var importJSONText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                wageAndRulesCard
                aiEngineConfigCard
                backupAndMigrationCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .sheet(isPresented: $showImportJSONSheet) {
            importBackupJSONModal
        }
    }

    private var wageAndRulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("薪資與全勤計算規則", systemImage: "dollarsign.gauge.chart.lefthalf.righthalf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("基本時薪 ($/hr)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    TextField("200", value: $vm.state.settings.hourlyWage, format: .number)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .padding(10)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .onChange(of: vm.state.settings.hourlyWage) { _, _ in vm.save() }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("全勤獎金 ($)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    TextField("500", value: $vm.state.settings.attendanceBonus, format: .number)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .padding(10)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .onChange(of: vm.state.settings.attendanceBonus) { _, _ in vm.save() }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("加班費倍率（目前：×\(String(format: "%g", vm.state.settings.otMultiplier))）")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 6) {
                    ForEach([1.0, 1.34, 1.67, 2.0], id: \.self) { mult in
                        let active = abs(vm.state.settings.otMultiplier - mult) < 0.001
                        Button {
                            KeyboardDismissManager.dismiss()
                            vm.state.settings.otMultiplier = mult
                            HapticsManager.shared.lightTap()
                            vm.save()
                        } label: {
                            Text(mult == 1.0 ? "1.0x 同薪" : "×\(String(format: "%.2f", mult))")
                                .font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(active ? Color(hex: "#0A84FF") : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text("自訂倍率 ×")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                    TextField("1.34", value: $vm.state.settings.otMultiplier, format: .number)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .onChange(of: vm.state.settings.otMultiplier) { _, _ in vm.save() }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("小數點進位機制").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                Picker("進位模式", selection: $vm.state.settings.roundingMode) {
                    ForEach(RoundingMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.state.settings.roundingMode) { _, _ in vm.save() }

                Text(vm.state.settings.roundingMode.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
