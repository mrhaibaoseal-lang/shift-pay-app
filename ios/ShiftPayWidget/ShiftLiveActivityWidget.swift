import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit

struct ShiftLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftLiveActivityAttributes.self) { context in
            // 鎖定畫面 / 通知中心即時薪資跳錶面板
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(context.state.shiftName, systemImage: "briefcase.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text(context.state.timeRange)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("本月 \(PayrollEngine.formatMoney(context.state.monthTotalPay))")
                        .font(.system(size: 13, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: "#30D158"))
                }

                ProgressView(value: min(1.0, max(0.05, context.state.progress)))
                    .tint(Color(hex: "#0A84FF"))

                HStack {
                    Text(context.state.statusHint)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#64D2FF"))
                    Spacer()
                    if context.state.otMinutes > 0 {
                        Text("累計加班 +\(context.state.otMinutes)m")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#FFD60A"))
                    }
                }
            }
            .padding(14)
            .activityBackgroundTint(Color(hex: "#14233B"))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.shiftName)
                            .font(.system(size: 12, weight: .bold))
                        Text(context.state.timeRange)
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(PayrollEngine.formatMoney(context.state.monthTotalPay))
                            .font(.system(size: 14, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: "#30D158"))
                        Text("本班 +\(PayrollEngine.formatMoney(context.state.currentShiftPay))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#FFD60A"))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.statusHint)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "#64D2FF"))
                        Spacer()
                    }
                }
            } compactLeading: {
                Text("💼 \(context.state.shiftName)")
                    .font(.system(size: 11, weight: .bold))
            } compactTrailing: {
                Text(PayrollEngine.formatMoney(context.state.monthTotalPay))
                    .font(.system(size: 11, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "#30D158"))
            } minimal: {
                Text("💰")
            }
        }
    }
}
#endif
