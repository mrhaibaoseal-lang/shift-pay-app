import SwiftUI

extension BillTabView {

    func dailyDetailCard(comp: PayrollEngine.MonthComputation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📋 每日工時與加班費明細")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("點選任一列可微調")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if comp.rows.isEmpty {
                Text("本月尚無排班紀錄，可至「排班」分頁蓋章或點右上角「拍班表匯入」")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                ForEach(comp.rows) { row in
                    Button {
                        vm.editingDateKey = row.key
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: row.shift.color))
                                .frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text("\(row.month)/\(row.day)(\(row.weekdayText))")
                                        .font(.system(size: 13, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundStyle(.white)
                                    Text(row.shift.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color(hex: row.shift.color).opacity(0.25), in: RoundedRectangle(cornerRadius: 5))
                                        .foregroundStyle(.white)
                                    if row.shift.status == .swap {
                                        Text("代班").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#64D2FF"))
                                    } else if row.shift.status == .leave {
                                        Text(row.shift.leaveType.badgeText).font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#FF453A"))
                                    }
                                }
                                Text("\(row.shift.start)-\(row.shift.end) · 正常 \(PayrollEngine.formatHours(row.normalMin))h\(row.otMin > 0 ? " · 加班 +\(row.otMin)分" : "")")
                                    .font(.system(size: 11))
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Text(PayrollEngine.formatMoneySmart(row.totalDayPay))
                                .font(.system(size: 14, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    Divider().background(.white.opacity(0.06))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    func buildStatementPlainText(comp: PayrollEngine.MonthComputation, settings: PayrollSettings) -> String {
        var lines: [String] = [
            "📋 \(settings.myName)｜\(vm.viewYear)年\(vm.viewMonth)月 打工薪資對帳單",
            "時薪：$\(Int(settings.hourlyWage))｜加班倍率：×\(String(format: "%g", settings.otMultiplier))",
            "────────────────────"
        ]
        for r in comp.rows {
            let otStr = r.otMin > 0 ? " + 加班\(r.otMin)m" : ""
            lines.append("\(r.month)/\(r.day)(\(r.weekdayText)) \(r.shift.start)-\(r.shift.end) (\(PayrollEngine.formatHours(r.normalMin))h\(otStr)) = \(PayrollEngine.formatMoneySmart(r.totalDayPay))")
        }
        lines.append("────────────────────")
        lines.append("正常工時：\(PayrollEngine.formatHours(comp.normalMinTotal)) 小時 (\(PayrollEngine.formatMoney(comp.normalPay)))")
        lines.append("累計加班：\(comp.otMinTotal) 分鐘 (\(PayrollEngine.formatMoney(comp.otPay)))")
        lines.append("全勤獎金：\(PayrollEngine.formatMoney(comp.bonus)) (\(comp.bonusOk ? "全勤達成" : "未達成"))")
        lines.append("💰 應領總薪資：\(PayrollEngine.formatMoney(comp.total))")
        return lines.joined(separator: "\n")
    }
}
