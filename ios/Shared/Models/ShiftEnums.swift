import Foundation
import SwiftUI

public enum ShiftPayConstants {
    public static let legacyStorageKey = "shiftpay.v1"
    public static let defaultAIModel = "gemini-3.8-flash"
    public static let defaultClaudeModel = "claude-sonnet-4-6"
    public static let defaultBreakMins: [Int] = [0, 30, 60, 90, 120]
    public static let weekDays: [String] = ["日", "一", "二", "三", "四", "五", "六"]
    public static let palette: [String] = [
        "#0A84FF", "#BF5AF2", "#FF9F0A", "#30D158", "#FF453A",
        "#FF375F", "#64D2FF", "#FFD60A", "#AC8E68", "#8E8E93"
    ]
}

public enum AIProviderTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleFoundation = "apple_foundation"
    case hybridDynamic   = "hybrid_dynamic"
    case gemini          = "gemini"
    case claude          = "claude"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .appleFoundation:
            return "🍎 Apple Foundation Models (裝置端 + Vision)"
        case .hybridDynamic:
            return "⚡ DynamicProfile 智慧混合 (Vision 定位 + 雲端大模型)"
        case .gemini:
            return "✨ Google Gemini 多模態模型"
        case .claude:
            return "🤖 Anthropic Claude 多模態模型"
        }
    }

    public var shortBadge: String {
        switch self {
        case .appleFoundation: return "Apple 內建 AI"
        case .hybridDynamic:   return "Dynamic 混合"
        case .gemini:          return "Gemini"
        case .claude:          return "Claude"
        }
    }

    public var subtitle: String {
        switch self {
        case .appleFoundation:
            return "免 API Key、離線可用、100% 隱私，搭配 Apple Vision 表格座標與 OCR 辨識"
        case .hybridDynamic:
            return "iOS 27 DynamicProfile：先用裝置端 Vision 鎖定姓名列與日期格，再動態切換雲端模型判讀手寫"
        case .gemini:
            return "支援多張班表跨頁合併與結構化輸出 (預設 gemini-3.8-flash)"
        case .claude:
            return "透過統一 LanguageModel 協定串接 Claude Sonnet 高精度視覺辨識"
        }
    }
}

public enum RoundingMode: String, Codable, CaseIterable, Sendable {
    case monthly = "monthly"
    case daily = "daily"

    public var title: String {
        switch self {
        case .monthly: return "整月加總後四捨五入"
        case .daily:   return "單日各自四捨五入"
        }
    }

    public var hint: String {
        switch self {
        case .monthly:
            return "（預設）把整月加班分鐘數加總後，計算金額再四捨五入一次，最精準。"
        case .daily:
            return "每天的加班費先各自四捨五入成整數，再加總成月薪。"
        }
    }
}

public enum AttendanceStatus: String, Codable, CaseIterable, Sendable {
    case normal = "normal"
    case swap   = "swap"
    case leave  = "leave"

    public var title: String {
        switch self {
        case .normal: return "正常出勤"
        case .swap:   return "代班"
        case .leave:  return "請假 / 遲到"
        }
    }
}

public enum LeaveSubType: String, Codable, CaseIterable, Sendable {
    case late  = "late"
    case leave = "leave"

    public var title: String {
        switch self {
        case .late:  return "遲到（扣全勤、工時照算）"
        case .leave: return "請假（扣全勤、當日不計薪）"
        }
    }

    public var badgeText: String {
        switch self {
        case .late:  return "遲到"
        case .leave: return "請假"
        }
    }
}

public struct ReminderSettings: Codable, Equatable, Sendable {
    public var prevDayEnabled: Bool
    public var prevDayTime: String
    public var wakeEnabled: Bool
    public var wakeLeadMin: Int
    public var autoSyncCalendar: Bool
    public var autoScheduleNotifications: Bool

    public init(
        prevDayEnabled: Bool = true,
        prevDayTime: String = "21:00",
        wakeEnabled: Bool = true,
        wakeLeadMin: Int = 90,
        autoSyncCalendar: Bool = false,
        autoScheduleNotifications: Bool = true
    ) {
        self.prevDayEnabled = prevDayEnabled
        self.prevDayTime = prevDayTime
        self.wakeEnabled = wakeEnabled
        self.wakeLeadMin = wakeLeadMin
        self.autoSyncCalendar = autoSyncCalendar
        self.autoScheduleNotifications = autoScheduleNotifications
    }

    enum CodingKeys: String, CodingKey {
        case prevDayEnabled, prevDayTime, wakeEnabled, wakeLeadMin
        case autoSyncCalendar, autoScheduleNotifications
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.prevDayEnabled = try c.decodeIfPresent(Bool.self, forKey: .prevDayEnabled) ?? true
        self.prevDayTime = try c.decodeIfPresent(String.self, forKey: .prevDayTime) ?? "21:00"
        self.wakeEnabled = try c.decodeIfPresent(Bool.self, forKey: .wakeEnabled) ?? true
        let rawLead = try c.decodeIfPresent(Int.self, forKey: .wakeLeadMin) ?? 90
        self.wakeLeadMin = max(5, min(720, rawLead))
        self.autoSyncCalendar = try c.decodeIfPresent(Bool.self, forKey: .autoSyncCalendar) ?? false
        self.autoScheduleNotifications = try c.decodeIfPresent(Bool.self, forKey: .autoScheduleNotifications) ?? true
    }
}
