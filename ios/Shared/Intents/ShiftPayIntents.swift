import Foundation
import AppIntents

/// 桌面互動式 Widget 與 Siri 捷徑：一鍵加記今日加班分鐘數
public struct AddQuickOvertimeIntent: AppIntent {
    public static let title: LocalizedStringResource = "快速加記今日加班"
    public static let description = IntentDescription("直接在桌面小工具或透過 Siri 為今天加上加班分鐘數，並即時重算本月薪資。")

    @Parameter(title: "加班分鐘數", default: 15)
    public var minutes: Int

    public init() {
        self.minutes = 15
    }

    public init(minutes: Int) {
        self.minutes = minutes
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        SharedStore.shared.addQuickOvertimeFromWidget(minutes: minutes)
        let payload = SharedStore.shared.loadWidgetPayload()
        return .result(dialog: "已幫您加記 \(minutes) 分鐘加班！本月預估總薪資更新為 \(PayrollEngine.formatMoney(payload.totalPay))。")
    }
}

/// Siri AI 語音查詢：查詢本月累積薪資與下一班起床時間
public struct QueryMonthlyPayIntent: AppIntent {
    public static let title: LocalizedStringResource = "查詢本月打工薪資與起床鬧鐘"
    public static let description = IntentDescription("向 Siri 詢問本月目前累積的打工薪資、全勤達成狀態以及下一班的建議起床時間。")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let payload = SharedStore.shared.loadWidgetPayload()
        let nextStr: String
        if let nx = payload.nextShift {
            nextStr = "下一班是\(nx.label) \(nx.time)的\(nx.name)，建議起床時間為 \(nx.wakeTime)。"
        } else {
            nextStr = "近期尚無排班，可以好好休息！"
        }
        return .result(dialog: "您\(payload.monthTitle)目前已排班 \(payload.shiftDays) 天，預估總薪資為 \(PayrollEngine.formatMoney(payload.totalPay))（\(payload.bonusStatusText)）。\(nextStr)")
    }
}

/// 取得下一班建議起床鬧鐘時間（可於 iOS 捷徑直接串接「建立鬧鐘」寫入系統時鐘 App）
public struct GetNextWakeAlarmIntent: AppIntent {
    public static let title: LocalizedStringResource = "取得下一班起床鬧鐘時間"
    public static let description = IntentDescription("回傳下一班或明日排班的建議起床時間（HH:MM），可直接串接 iOS 內建「建立鬧鐘」動作自動新增系統時鐘鬧鐘。")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let payload = SharedStore.shared.loadWidgetPayload()
        if let nx = payload.nextShift {
            return .result(
                value: nx.wakeTime,
                dialog: "下一班是\(nx.label) \(nx.time)（\(nx.name)），建議起床鬧鐘時間為 \(nx.wakeTime)。"
            )
        }
        return .result(value: "", dialog: "近期尚無排班，不需設定起床鬧鐘。")
    }
}

public struct ShiftPayAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QueryMonthlyPayIntent(),
            phrases: [
                "用\(.applicationName)查詢本月薪水",
                "問\(.applicationName)我這個月賺多少錢",
                "用\(.applicationName)看明天幾點起床上班"
            ],
            shortTitle: "查詢本月薪資與起床時間",
            systemImageName: "dollarsign.circle.fill"
        )
        AppShortcut(
            intent: GetNextWakeAlarmIntent(),
            phrases: [
                "用\(.applicationName)取得起床鬧鐘時間",
                "用\(.applicationName)同步打工起床鬧鐘"
            ],
            shortTitle: "取得下一班起床鬧鐘時間",
            systemImageName: "alarm.fill"
        )
        AppShortcut(
            intent: AddQuickOvertimeIntent(),
            phrases: [
                "用\(.applicationName)記錄今日加班",
                "幫我在\(.applicationName)加上加班"
            ],
            shortTitle: "快速記加班",
            systemImageName: "bolt.fill"
        )
    }
}
