import Foundation

public struct PayrollSettings: Codable, Equatable, Sendable {
    public var hourlyWage: Double
    public var otMultiplier: Double
    public var roundingMode: RoundingMode
    public var attendanceBonus: Double
    public var myName: String
    public var apiKey: String
    public var claudeApiKey: String
    public var aiProvider: AIProviderTier
    public var aiModel: String
    public var aiModelCustom: Bool?
    public var codeHints: String
    public var customBreaks: [Int]
    public var reminders: ReminderSettings

    public init(
        hourlyWage: Double = 200,
        otMultiplier: Double = 1.0,
        roundingMode: RoundingMode = .monthly,
        attendanceBonus: Double = 500,
        myName: String = "王凱弘",
        apiKey: String = "",
        claudeApiKey: String = "",
        aiProvider: AIProviderTier = .hybridDynamic,
        aiModel: String = ShiftPayConstants.defaultAIModel,
        aiModelCustom: Bool? = true,
        codeHints: String = ShiftPayConstants.defaultCodeHints,
        customBreaks: [Int] = [],
        reminders: ReminderSettings = ReminderSettings()
    ) {
        self.hourlyWage = hourlyWage
        self.otMultiplier = otMultiplier
        self.roundingMode = roundingMode
        self.attendanceBonus = attendanceBonus
        self.myName = myName
        self.apiKey = apiKey
        self.claudeApiKey = claudeApiKey
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.aiModelCustom = aiModelCustom
        self.codeHints = codeHints
        self.customBreaks = customBreaks
        self.reminders = reminders
    }

    enum CodingKeys: String, CodingKey {
        case hourlyWage, otMultiplier, roundingMode, attendanceBonus, myName
        case apiKey, claudeApiKey, aiProvider, aiModel, aiModelCustom
        case codeHints, customBreaks, reminders
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hourlyWage = try c.decodeIfPresent(Double.self, forKey: .hourlyWage) ?? 200
        self.otMultiplier = try c.decodeIfPresent(Double.self, forKey: .otMultiplier) ?? 1.0
        self.roundingMode = try c.decodeIfPresent(RoundingMode.self, forKey: .roundingMode) ?? .monthly
        self.attendanceBonus = try c.decodeIfPresent(Double.self, forKey: .attendanceBonus) ?? 500
        let name = try c.decodeIfPresent(String.self, forKey: .myName)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.myName = (name?.isEmpty == false) ? name! : "王凱弘"
        self.apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        self.claudeApiKey = try c.decodeIfPresent(String.self, forKey: .claudeApiKey) ?? ""
        self.aiProvider = try c.decodeIfPresent(AIProviderTier.self, forKey: .aiProvider) ?? .hybridDynamic
        let rawModel = try c.decodeIfPresent(String.self, forKey: .aiModel) ?? ShiftPayConstants.defaultAIModel
        self.aiModel = (rawModel.isEmpty || rawModel == "gemini-2.5-flash") ? ShiftPayConstants.defaultAIModel : rawModel
        self.aiModelCustom = try c.decodeIfPresent(Bool.self, forKey: .aiModelCustom)
        let rawHints = (try c.decodeIfPresent(String.self, forKey: .codeHints) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.codeHints = rawHints.isEmpty ? ShiftPayConstants.defaultCodeHints : rawHints
        let rawBreaks = try c.decodeIfPresent([Int].self, forKey: .customBreaks) ?? []
        self.customBreaks = Array(Set(rawBreaks.filter { $0 > 0 && $0 <= 720 })).sorted()
        self.reminders = try c.decodeIfPresent(ReminderSettings.self, forKey: .reminders) ?? ReminderSettings()
    }
}
