import Foundation

public struct ShiftStamp: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var start: String
    public var end: String
    public var breakMin: Int
    public var color: String

    public init(
        id: String = "s" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36),
        name: String,
        start: String,
        end: String,
        breakMin: Int = 0,
        color: String = "#0A84FF"
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.breakMin = breakMin
        self.color = color
    }

    public static let defaultStamps: [ShiftStamp] = [
        ShiftStamp(id: "s1", name: "整天班", start: "10:30", end: "21:00", breakMin: 120, color: "#FF9F0A"),
        ShiftStamp(id: "s2", name: "晚班(平日)", start: "16:30", end: "21:00", breakMin: 0, color: "#BF5AF2"),
        ShiftStamp(id: "s3", name: "晚班(假日)", start: "17:00", end: "21:00", breakMin: 0, color: "#FF375F"),
        ShiftStamp(id: "s4", name: "早班(平日)", start: "10:30", end: "14:30", breakMin: 0, color: "#0A84FF"),
        ShiftStamp(id: "s5", name: "早班(假日)", start: "10:30", end: "15:00", breakMin: 0, color: "#64D2FF")
    ]

    public static func isLegacyDefaultStamps(_ stamps: [ShiftStamp]) -> Bool {
        if stamps.count == 3 {
            return stamps[0].start == "09:00" && stamps[0].end == "17:00" &&
                   stamps[1].start == "18:00" && stamps[1].end == "22:00" &&
                   stamps[2].start == "10:00" && stamps[2].end == "19:00"
        }
        if stamps.count == 5 && stamps[2].name == "晚班(假日)" && stamps[2].start == "17:30" {
            return true
        }
        return false
    }
}

public struct ShiftRecord: Codable, Equatable, Sendable {
    public var name: String
    public var color: String
    public var start: String
    public var end: String
    public var breakMin: Int
    public var stampId: String?
    public var otMin: Int
    public var status: AttendanceStatus
    public var leaveType: LeaveSubType
    public var note: String

    public init(
        name: String,
        color: String = "#0A84FF",
        start: String,
        end: String,
        breakMin: Int = 0,
        stampId: String? = nil,
        otMin: Int = 0,
        status: AttendanceStatus = .normal,
        leaveType: LeaveSubType = .late,
        note: String = ""
    ) {
        self.name = name
        self.color = color
        self.start = start
        self.end = end
        self.breakMin = breakMin
        self.stampId = stampId
        self.otMin = otMin
        self.status = status
        self.leaveType = leaveType
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case name, color, start, end, breakMin, stampId, otMin, status, leaveType, note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? "班表"
        self.color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#0A84FF"
        self.start = try c.decodeIfPresent(String.self, forKey: .start) ?? "09:00"
        self.end = try c.decodeIfPresent(String.self, forKey: .end) ?? "17:00"
        self.breakMin = try c.decodeIfPresent(Int.self, forKey: .breakMin) ?? 0
        self.stampId = try c.decodeIfPresent(String.self, forKey: .stampId)
        self.otMin = max(0, try c.decodeIfPresent(Int.self, forKey: .otMin) ?? 0)
        self.status = try c.decodeIfPresent(AttendanceStatus.self, forKey: .status) ?? .normal
        self.leaveType = try c.decodeIfPresent(LeaveSubType.self, forKey: .leaveType) ?? .late
        self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

public struct ShiftPayState: Codable, Equatable, Sendable {
    public var settings: PayrollSettings
    public var stamps: [ShiftStamp]
    public var shifts: [String: ShiftRecord]

    public init(
        settings: PayrollSettings = PayrollSettings(),
        stamps: [ShiftStamp] = ShiftStamp.defaultStamps,
        shifts: [String: ShiftRecord] = [:]
    ) {
        self.settings = settings
        self.stamps = stamps
        self.shifts = shifts
    }

    enum CodingKeys: String, CodingKey {
        case settings, stamps, shifts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.settings = try c.decodeIfPresent(PayrollSettings.self, forKey: .settings) ?? PayrollSettings()
        let decodedStamps = try c.decodeIfPresent([ShiftStamp].self, forKey: .stamps) ?? ShiftStamp.defaultStamps
        self.stamps = (decodedStamps.isEmpty || ShiftStamp.isLegacyDefaultStamps(decodedStamps)) ? ShiftStamp.defaultStamps : decodedStamps
        self.shifts = try c.decodeIfPresent([String: ShiftRecord].self, forKey: .shifts) ?? [:]
    }
}
