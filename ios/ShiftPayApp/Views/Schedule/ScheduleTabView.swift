import SwiftUI

struct ScheduleTabView: View {
    @Bindable var vm: ShiftPayViewModel

    var body: some View {
        let comp = vm.currentMonthComputation
        ScrollView {
            VStack(spacing: 14) {
                salaryHeaderCard(comp: comp)
                    .horizontalMonthSwipe(vm: vm)
                stampToolbarSection
                calendarGridCard
                    .horizontalMonthSwipe(vm: vm)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private func salaryHeaderCard(comp: PayrollEngine.MonthComputation) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vm.viewMonth) 月預估總薪資（\(comp.paydayHint)）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(PayrollEngine.formatMoney(comp.total))
                    .font(.system(size: 32, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("正常 \(PayrollEngine.formatHours(comp.normalMinTotal))h (\(PayrollEngine.formatMoney(comp.normalPay))) · 加班 \(comp.otMinTotal)分 (\(PayrollEngine.formatMoney(comp.otPay))) · 共 \(comp.days.count) 天")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            attendanceBadge(comp: comp)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(hex: "#14233B"), Color(hex: "#1C1C1E")], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private func attendanceBadge(comp: PayrollEngine.MonthComputation) -> some View {
        if !comp.hasShift {
            Text("⏳ 尚未排班")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.1), in: Capsule())
                .foregroundStyle(.white.opacity(0.55))
        } else if comp.bonusOk {
            VStack(alignment: .trailing, spacing: 2) {
                Text("🏅 全勤達成").font(.system(size: 11, weight: .bold))
                Text("+\(PayrollEngine.formatMoney(comp.bonus))").font(.system(size: 12, weight: .heavy)).monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.35), lineWidth: 1))
            .foregroundStyle(Color(hex: "#30D158"))
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text("⚠️ 已扣全勤").font(.system(size: 11, weight: .bold))
                Text("請假/遲到 \(comp.leaveCount)天").font(.system(size: 10))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.35), lineWidth: 1))
            .foregroundStyle(Color(hex: "#FF453A"))
        }
    }
}
