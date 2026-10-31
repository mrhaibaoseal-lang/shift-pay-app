import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

public struct WidgetNextShiftInfo: Codable, Equatable, Sendable {
    public var date: String
    public var label: String
    public var name: String
    public var color: String
    public var time: String
    public var wakeTime: String

    public init(date: String, label: String, name: String, color: String, time: String, wakeTime: String) {
        self.date = date
        self.label = label
        self.name = name
        self.color = color
        self.time = time
        self.wakeTime = wakeTime
    }
}

public struct WidgetSyncPayload: Codable, Equatable, Sendable {
    public var app: String
    public var updatedAt: String
    public var month: String
    public var monthTitle: String
    public var paydayHint: String
    public var totalPay: Int
    public var normalPay: Int
    public var otPay: Int
    public var bonusPay: Int
    public var bonusOk: Bool
    public var bonusStatusText: String
    public var normalHours: String
    public var otMinutes: Int
    public var shiftDays: Int
    public var nextShift: WidgetNextShiftInfo?

    public init(
        app: String = "shiftpay-v3-ios27",
        updatedAt: String = ISO8601DateFormatter().string(from: Date()),
        month: String,
        monthTitle: String,
        paydayHint: String,
        totalPay: Int,
        normalPay: Int,
        otPay: Int,
        bonusPay: Int,
        bonusOk: Bool,
        bonusStatusText: String,
        normalHours: String,
        otMinutes: Int,
        shiftDays: Int,
        nextShift: WidgetNextShiftInfo?
    ) {
        self.app = app
        self.updatedAt = updatedAt
        self.month = month
        self.monthTitle = monthTitle
        self.paydayHint = paydayHint
        self.totalPay = totalPay
        self.normalPay = normalPay
        self.otPay = otPay
        self.bonusPay = bonusPay
        self.bonusOk = bonusOk
        self.bonusStatusText = bonusStatusText
        self.normalHours = normalHours
        self.otMinutes = otMinutes
        self.shiftDays = shiftDays
        self.nextShift = nextShift
    }
}

public struct ExtractedShiftRow: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: String
    public var startTime: String
    public var endTime: String
    public var note: String
    public var checked: Bool
    public var needsReview: Bool

    public init(
        id: UUID = UUID(),
        date: String,
        startTime: String,
        endTime: String,
        note: String = "",
        checked: Bool = true,
        needsReview: Bool = false
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.checked = checked
        self.needsReview = needsReview
    }
}

#if canImport(ActivityKit)
public struct ShiftLiveActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var shiftName: String
        public var timeRange: String
        public var currentShiftPay: Int
        public var monthTotalPay: Int
        public var otMinutes: Int
        public var progress: Double
        public var statusHint: String

        public init(
            shiftName: String,
            timeRange: String,
            currentShiftPay: Int,
            monthTotalPay: Int,
            otMinutes: Int,
            progress: Double,
            statusHint: String
        ) {
            self.shiftName = shiftName
            self.timeRange = timeRange
            self.currentShiftPay = currentShiftPay
            self.monthTotalPay = monthTotalPay
            self.otMinutes = otMinutes
            self.progress = progress
            self.statusHint = statusHint
        }
    }

    public var employeeName: String
    public var hourlyWage: Int

    public init(employeeName: String, hourlyWage: Int) {
        self.employeeName = employeeName
        self.hourlyWage = hourlyWage
    }
}
#endif

extension Color {
    public init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 10, 132, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
