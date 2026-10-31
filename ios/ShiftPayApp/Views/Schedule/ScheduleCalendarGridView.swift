import SwiftUI

extension ScheduleTabView {

    var calendarGridCard: some View {
        let firstKey = PayrollEngine.dateKey(year: vm.viewYear, month: vm.viewMonth, day: 1)
        let firstWeekday = PayrollEngine.weekdayIndex(of: firstKey)
        let daysCount = PayrollEngine.daysInMonth(year: vm.viewYear, month: vm.viewMonth)

        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let todayKey = PayrollEngine.dateKey(
            year: cal.component(.year, from: now),
            month: cal.component(.month, from: now),
            day: cal.component(.day, from: now)
        )

        return VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(0..<7, id: \.self) { idx in
                    Text(ShiftPayConstants.weekDays[idx])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(idx == 0 ? Color(hex: "#FF453A") : (idx == 6 ? Color(hex: "#0A84FF") : .white.opacity(0.45)))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }

                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 68)
                }

                ForEach(1...daysCount, id: \.self) { day in
                    let key = PayrollEngine.dateKey(year: vm.viewYear, month: vm.viewMonth, day: day)
                    let shift = vm.state.shifts[key]
                    let weekday = (firstWeekday + day - 1) % 7
                    calendarDayCell(day: day, dateKey: key, weekday: weekday, shift: shift, isToday: key == todayKey)
                }
            }

            HStack {
                Text("💡 左右滑動月曆可切換月份 · 點擊日期可微調時間、休息或記錄加班")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(Rectangle())
    }

    private func calendarDayCell(day: Int, dateKey: String, weekday: Int, shift: ShiftRecord?, isToday: Bool) -> some View {
        let dayColor: Color = weekday == 0 ? Color(hex: "#FF453A") : (weekday == 6 ? Color(hex: "#0A84FF") : .white.opacity(0.85))
        return Button {
            vm.handleCalendarDayTap(dateKey: dateKey)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 2) {
                    Text("\(day)")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(dayColor)
                    Spacer(minLength: 0)
                    if let sh = shift {
                        if sh.status == .swap {
                            Text("代")
                                .font(.system(size: 8, weight: .heavy))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.cyan.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(Color(hex: "#64D2FF"))
                        } else if sh.status == .leave {
                            Text(sh.leaveType == .leave ? "假" : "遲")
                                .font(.system(size: 8, weight: .heavy))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.28), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(Color(hex: "#FF453A"))
                        }
                    }
                }

                Spacer(minLength: 0)

                if let sh = shift {
                    let isUnpaid = PayrollEngine.isUnpaidLeave(sh)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sh.name)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                        Text(isUnpaid ? "不計薪" : "\(sh.start)")
                            .font(.system(size: 9, weight: .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .foregroundStyle(.white.opacity(0.9))
                        if sh.otMin > 0 && !isUnpaid {
                            Text("+\(sh.otMin)m")
                                .font(.system(size: 8, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(Color(hex: "#FFD60A"))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(hex: sh.color).opacity(isUnpaid ? 0.35 : 0.85),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                }
            }
            .padding(5)
            .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68, alignment: .topLeading)
            .background(Color.white.opacity(shift != nil ? 0.06 : 0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isToday ? Color(hex: "#0A84FF") : .white.opacity(0.05), lineWidth: isToday ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
