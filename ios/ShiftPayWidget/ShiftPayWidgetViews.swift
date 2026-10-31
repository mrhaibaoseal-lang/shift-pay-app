import WidgetKit
import SwiftUI
import AppIntents

struct ShiftPayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ShiftPayWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreenView(p: entry.payload)
        case .systemSmall:
            smallWidgetView(p: entry.payload)
        default:
            mediumWidgetView(p: entry.payload)
        }
    }

    private func lockScreenView(p: WidgetSyncPayload) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("💰 \(p.monthTitle) \(PayrollEngine.formatMoney(p.totalPay))・\(p.bonusStatusText)")
                .font(.system(size: 12, weight: .bold))
            if let nx = p.nextShift {
                Text("下一班 \(nx.label) \(nx.time)").font(.system(size: 11))
                Text("⏰ 建議起床：\(nx.wakeTime)").font(.system(size: 11, weight: .bold))
            } else {
                Text("🎉 近期尚無排班").font(.system(size: 11))
            }
        }
    }

    private func smallWidgetView(p: WidgetSyncPayload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("💰 \(p.monthTitle)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(p.bonusOk ? "🔥全勤" : "⚠️無全勤")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(p.bonusOk ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
            }

            Text(PayrollEngine.formatMoney(p.totalPay))
                .font(.system(size: 22, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let nx = p.nextShift {
                Text("\(nx.label) \(nx.time)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text("⏰ 起床 \(nx.wakeTime)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(hex: "#64D2FF"))
            } else {
                Text("🎉 近期無排班")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#30D158"))
            }
        }
    }

    private func mediumWidgetView(p: WidgetSyncPayload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("💰 \(p.monthTitle)累積 (\(p.paydayHint))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                Spacer()
                Text(p.bonusStatusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(p.bonusOk ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(PayrollEngine.formatMoney(p.totalPay))
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 6) {
                    Button(intent: AddQuickOvertimeIntent(minutes: 15)) {
                        Text("⚡+15m")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.25), in: Capsule())
                            .foregroundStyle(Color(hex: "#FFD60A"))
                    }
                    .buttonStyle(.plain)

                    Button(intent: AddQuickOvertimeIntent(minutes: 30)) {
                        Text("⚡+30m")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.28), in: Capsule())
                            .foregroundStyle(Color(hex: "#64D2FF"))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().background(.white.opacity(0.15))

            if let nx = p.nextShift {
                HStack {
                    Text("🔥 下一班：\(nx.label) \(nx.time)（\(nx.name)）")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                    Text("⏰ 起床 \(nx.wakeTime)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(hex: "#64D2FF"))
                }
            } else {
                Text("🎉 近期尚無排班，好好休息！（累計加班 \(p.otMinutes) 分）")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#30D158"))
            }
        }
    }
}
