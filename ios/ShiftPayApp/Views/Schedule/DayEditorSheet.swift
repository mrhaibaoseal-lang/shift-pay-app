import SwiftUI

struct DayEditorSheet: View {
    @Bindable var vm: ShiftPayViewModel
    let dateKey: String
    @Environment(\.dismiss) var dismiss
    @State var customBreakInput: String = ""

    var shift: ShiftRecord? {
        vm.state.shifts[dateKey]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickStampPickerSection

                    if let sh = shift {
                        timeAndBreakSection(sh: sh)
                        overtimeSection(sh: sh)
                        attendanceStatusSection(sh: sh)
                        noteAndDeleteSection(sh: sh)
                    } else {
                        emptyShiftPlaceholder
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                Color(hex: "#1C1C1E")
                    .ignoresSafeArea()
                    .onTapGesture { KeyboardDismissManager.dismiss() }
            )
            .navigationTitle(formattedDateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        KeyboardDismissManager.dismiss()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .dismissKeyboardOnTap()
        }
    }

    private var formattedDateTitle: String {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dateKey }
        let wd = ShiftPayConstants.weekDays[PayrollEngine.weekdayIndex(of: dateKey)]
        return "\(parts[1]) 月 \(parts[2]) 日（週\(wd)）"
    }

    private var quickStampPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("套用常用班別")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.state.stamps) { st in
                        let isCurrent = (shift?.stampId == st.id)
                        Button {
                            vm.applyStamp(dateKey: dateKey, stampId: st.id)
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: st.color)).frame(width: 8, height: 8)
                                Text("\(st.name) \(st.start)-\(st.end)")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isCurrent ? Color(hex: "#0A84FF") : .white.opacity(0.08), in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    private var emptyShiftPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
            Text("這天尚未排班，請點擊上方任一班別套用，或直接建立自訂班表")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Button {
                vm.state.shifts[dateKey] = ShiftRecord(name: "自訂班", color: "#0A84FF", start: "09:00", end: "17:00")
                vm.save()
            } label: {
                Text("➕ 建立自訂時間班表")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#0A84FF"), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}
