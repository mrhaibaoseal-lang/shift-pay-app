import SwiftUI

struct BillTabView: View {
    @Bindable var vm: ShiftPayViewModel

    var body: some View {
        let comp = vm.currentMonthComputation
        let s = vm.state.settings

        ScrollView {
            VStack(spacing: 14) {
                summaryHeroCard(comp: comp, settings: s)
                dailyDetailCard(comp: comp)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .horizontalMonthSwipe(vm: vm)
        .sheet(isPresented: $vm.showStatementPreviewSheet) {
            BillStatementSheet(vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func summaryHeroCard(comp: PayrollEngine.MonthComputation, settings: PayrollSettings) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vm.viewMonth) 月薪資總額拆解")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(PayrollEngine.formatMoney(comp.total))
                        .font(.system(size: 36, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("時薪 $\(Int(settings.hourlyWage)) · 加班 ×\(String(format: "%g", settings.otMultiplier)) · \(settings.roundingMode.title) · 已排 \(comp.days.count) 天")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                breakdownMiniCard(
                    title: "基本工時薪資",
                    icon: "clock.fill",
                    iconColor: Color(hex: "#0A84FF"),
                    amount: PayrollEngine.formatMoney(comp.normalPay),
                    sub: "共 \(PayrollEngine.formatHours(comp.normalMinTotal)) 小時"
                )
                breakdownMiniCard(
                    title: "分鐘級加班費",
                    icon: "bolt.fill",
                    iconColor: Color(hex: "#FFD60A"),
                    amount: PayrollEngine.formatMoney(comp.otPay),
                    sub: "累計 \(comp.otMinTotal) 分鐘"
                )
                breakdownMiniCard(
                    title: "全勤獎金",
                    icon: "medal.fill",
                    iconColor: comp.bonusOk ? Color(hex: "#30D158") : Color(hex: "#FF453A"),
                    amount: PayrollEngine.formatMoney(comp.bonus),
                    sub: !comp.hasShift ? "尚未排班" : (comp.bonusOk ? "全勤達成" : "請假/遲到 \(comp.leaveCount)天")
                )
            }

            HStack(spacing: 10) {
                Button {
                    HapticsManager.shared.lightTap()
                    vm.showStatementPreviewSheet = true
                } label: {
                    Label("月底對帳單長圖 / 分享", systemImage: "photo.badge.arrow.down.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                }

                Button {
                    UIPasteboard.general.string = buildStatementPlainText(comp: comp, settings: settings)
                    HapticsManager.shared.success()
                    vm.showToast("✅ 已複製文字版對帳單，可直接貼到 LINE！", style: .success)
                } label: {
                    Label("複製文字明細", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func breakdownMiniCard(title: String, icon: String, iconColor: Color, amount: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10)).foregroundStyle(iconColor)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
            Text(amount)
                .font(.system(size: 16, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
