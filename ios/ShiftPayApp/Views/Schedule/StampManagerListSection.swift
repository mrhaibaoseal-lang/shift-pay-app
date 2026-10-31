import SwiftUI

extension StampManagerSheet {

    var colorAndActionRow: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ShiftPayConstants.palette, id: \.self) { cHex in
                        Button { color = cHex } label: {
                            Circle()
                                .fill(Color(hex: cHex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if color == cHex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                if editingId != nil {
                    Button("取消") { resetForm() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                Button(editingId == nil ? "新增班別" : "儲存修改") {
                    saveStamp()
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#0A84FF"), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
        }
    }

    var existingStampsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已建立的班別印章")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            ForEach(vm.state.stamps) { st in
                HStack(spacing: 12) {
                    Circle().fill(Color(hex: st.color)).frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(st.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text("\(st.start)-\(st.end) · \(st.breakMin > 0 ? "扣休 \(PayrollEngine.formatHours(st.breakMin))h" : "不扣休息") · 工時 \(PayrollEngine.formatHours(PayrollEngine.stampWorkMinutes(st)))h")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Button {
                        editingId = st.id; name = st.name; start = st.start; end = st.end; breakMin = st.breakMin; color = st.color
                    } label: {
                        Image(systemName: "pencil").padding(8).background(.white.opacity(0.1), in: Circle())
                    }
                    Button(role: .destructive) {
                        vm.state.stamps.removeAll { $0.id == st.id }
                        if vm.activeStampId == st.id { vm.activeStampId = nil }
                        vm.save()
                    } label: {
                        Image(systemName: "trash").padding(8).background(Color.red.opacity(0.18), in: Circle())
                    }
                }
                .padding(12)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    func resetForm() {
        KeyboardDismissManager.dismiss()
        editingId = nil; name = ""; start = "09:00"; end = "17:00"; breakMin = 0
        color = ShiftPayConstants.palette[vm.state.stamps.count % ShiftPayConstants.palette.count]
    }

    func saveStamp() {
        KeyboardDismissManager.dismiss()
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { vm.showToast("請輸入班別名稱", style: .error); return }
        guard PayrollEngine.isValidHHMM(start), PayrollEngine.isValidHHMM(end) else {
            vm.showToast("時間格式需為 HH:MM（例如 09:00）", style: .error); return
        }
        if let eid = editingId, let idx = vm.state.stamps.firstIndex(where: { $0.id == eid }) {
            vm.state.stamps[idx] = ShiftStamp(id: eid, name: cleanName, start: start, end: end, breakMin: breakMin, color: color)
            vm.showToast("✅ 已更新班別", style: .success)
        } else {
            vm.state.stamps.append(ShiftStamp(name: cleanName, start: start, end: end, breakMin: breakMin, color: color))
            vm.showToast("✅ 已新增班別", style: .success)
        }
        vm.save()
        resetForm()
    }
}
