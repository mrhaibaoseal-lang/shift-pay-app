import SwiftUI

extension DayEditorSheet {

    func attendanceStatusSection(sh: ShiftRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("出勤狀態（影響全勤獎金判定）")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 8) {
                ForEach(AttendanceStatus.allCases, id: \.self) { st in
                    let active = (sh.status == st)
                    Button {
                        if st == .leave && sh.status != .leave {
                            HapticsManager.shared.warning()
                            vm.showToast("⚠️ 已觸發扣除全勤獎金 \(PayrollEngine.formatMoney(Int(vm.state.settings.attendanceBonus)))", style: .warning)
                        } else {
                            HapticsManager.shared.lightTap()
                        }
                        vm.state.shifts[dateKey]?.status = st
                        vm.save()
                    } label: {
                        Text(st.title)
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(active ? Color(hex: "#0A84FF") : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }
            }

            if sh.status == .leave {
                Picker("請假類型", selection: Binding(
                    get: { sh.leaveType },
                    set: { val in
                        vm.state.shifts[dateKey]?.leaveType = val
                        vm.save()
                    }
                )) {
                    ForEach(LeaveSubType.allCases, id: \.self) { sub in
                        Text(sub.title).tag(sub)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    func noteAndDeleteSection(sh: ShiftRecord) -> some View {
        VStack(spacing: 12) {
            TextField("備註（例如：店長調班、支援晚班）", text: Binding(
                get: { sh.note },
                set: { val in
                    vm.state.shifts[dateKey]?.note = val
                    vm.save()
                }
            ))
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            Button(role: .destructive) {
                vm.state.shifts.removeValue(forKey: dateKey)
                vm.save()
                vm.showToast("已刪除此日班表")
                dismiss()
            } label: {
                Label("刪除這天的排班", systemImage: "trash.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color(hex: "#FF453A"))
            }
        }
    }
}
