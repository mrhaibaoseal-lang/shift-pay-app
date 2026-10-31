import SwiftUI

struct StampManagerSheet: View {
    @Bindable var vm: ShiftPayViewModel
    @Environment(\.dismiss) private var dismiss

    @State var editingId: String? = nil
    @State var name: String = ""
    @State var start: String = "09:00"
    @State var end: String = "17:00"
    @State var breakMin: Int = 0
    @State var color: String = ShiftPayConstants.palette[0]
    @State var customBreakInput: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stampFormCard
                    existingStampsList
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                Color(hex: "#1C1C1E")
                    .ignoresSafeArea()
                    .onTapGesture { KeyboardDismissManager.dismiss() }
            )
            .navigationTitle("🏷️ 管理常用班別印章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        KeyboardDismissManager.dismiss()
                        dismiss()
                    }
                }
            }
            .dismissKeyboardOnTap()
        }
    }

    private var stampFormCard: some View {
        let breakOpts = PayrollEngine.allBreakOptions(customBreaks: vm.state.settings.customBreaks, currentValue: breakMin)

        return VStack(alignment: .leading, spacing: 12) {
            Text(editingId == nil ? "➕ 新增常用班別" : "✏️ 編輯班別")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            TextField("班別名稱（例如：早班、晚班、打烊班）", text: $name)
                .submitLabel(.done)
                .padding(11)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("上班時間").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    TextField("09:00", text: $start)
                        .submitLabel(.done)
                        .padding(10)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .monospacedDigit()
                        .onChange(of: start) { _, val in
                            let f = PayrollEngine.autoFormatTimeInput(val)
                            if f != val { start = f }
                        }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("下班時間").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    TextField("17:00", text: $end)
                        .submitLabel(.done)
                        .padding(10)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .monospacedDigit()
                        .onChange(of: end) { _, val in
                            let f = PayrollEngine.autoFormatTimeInput(val)
                            if f != val { end = f }
                        }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(breakOpts, id: \.self) { mins in
                    Button {
                        KeyboardDismissManager.dismiss()
                        breakMin = mins
                    } label: {
                        Text(PayrollEngine.formatBreakLabel(mins))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(breakMin == mins ? Color(hex: "#0A84FF") : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("自訂休息分鐘 (如 45)", text: $customBreakInput)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .padding(9)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                Button("新增常駐按鈕") {
                    KeyboardDismissManager.dismiss()
                    if let val = Int(customBreakInput.trimmingCharacters(in: .whitespacesAndNewlines)), val > 0 {
                        vm.addCustomBreakMinutes(val)
                        breakMin = val
                        customBreakInput = ""
                        vm.showToast("✅ 已新增 \(PayrollEngine.formatBreakLabel(val)) 常駐按鈕", style: .success)
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color(hex: "#64D2FF"))
            }

            colorAndActionRow
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}
