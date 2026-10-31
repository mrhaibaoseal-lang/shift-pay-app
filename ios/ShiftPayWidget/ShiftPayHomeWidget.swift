import WidgetKit
import SwiftUI
import AppIntents

struct ShiftPayWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSyncPayload
}

struct ShiftPayTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShiftPayWidgetEntry {
        ShiftPayWidgetEntry(date: Date(), payload: SharedStore.shared.loadWidgetPayload())
    }

    func getSnapshot(in context: Context, completion: @escaping (ShiftPayWidgetEntry) -> Void) {
        completion(ShiftPayWidgetEntry(date: Date(), payload: SharedStore.shared.loadWidgetPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftPayWidgetEntry>) -> Void) {
        let entry = ShiftPayWidgetEntry(date: Date(), payload: SharedStore.shared.loadWidgetPayload())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct ShiftPayHomeWidget: Widget {
    let kind: String = "ShiftPayHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShiftPayTimelineProvider()) { entry in
            ShiftPayWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "#14233B"), Color(hex: "#0F0F12")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("💰 打工薪水帳 & 起床鬧鐘")
        .description("即時顯示本月累積薪資、全勤燈號、下一班與建議起床時間，支援桌面直接點按 +15m/+30m 記加班！")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
