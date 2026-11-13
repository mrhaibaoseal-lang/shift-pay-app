import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

/// iOS 26+ AlarmKit 原生系統鬧鐘（與內建「時鐘」鬧鐘同等級：全螢幕響鈴、無視靜音與專注模式）
@MainActor
public final class NativeWakeAlarmService {
    public static let shared = NativeWakeAlarmService()

    /// 每個班次的起床鬧鐘數量（很難醒 → 連續三個）
    nonisolated public static let alarmsPerShift = 3

    private init() {}

    /// 此裝置是否支援 AlarmKit 原生鬧鐘
    public var isSupported: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    /// 請求原生鬧鐘權限；不支援時回傳 false
    public func requestAuthorization() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            switch manager.authorizationState {
            case .authorized:
                return true
            case .denied:
                return false
            case .notDetermined:
                let result = (try? await manager.requestAuthorization()) ?? .denied
                return result == .authorized
            @unknown default:
                return false
            }
        }
        #endif
        return false
    }

    /// 起床鬧鐘的響鈴時間：T、T+gap、T+2·gap
    nonisolated public static func ringOffsets(gapMinutes: Int) -> [Int] {
        let gap = max(1, gapMinutes)
        return (0..<alarmsPerShift).map { $0 * gap }
    }

    public struct WakeAlarmRequest {
        public let fireDate: Date
        public let title: String
    }

    /// 取消本 App 所有尚未響起的鬧鐘後，重新排程。回傳成功排程的鬧鐘數。
    @discardableResult
    public func replaceAll(with requests: [WakeAlarmRequest]) async -> Int {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            if let existing = try? manager.alarms {
                for alarm in existing where alarm.state != .alerting {
                    try? manager.cancel(id: alarm.id)
                }
            }
            var count = 0
            for req in requests where req.fireDate > Date() {
                if await schedule(fireDate: req.fireDate, title: req.title) { count += 1 }
            }
            return count
        }
        #endif
        return 0
    }

    /// 排程單一原生鬧鐘（也用於「立即測試」）
    @discardableResult
    public func schedule(fireDate: Date, title: String) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let stopButton = AlarmButton(text: "我醒了", textColor: .white, systemImageName: "sun.max.fill")
            let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), stopButton: stopButton)
            let attributes = AlarmAttributes<ShiftWakeAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: ShiftWakeAlarmMetadata(),
                tintColor: Color(red: 1.0, green: 0.62, blue: 0.04)
            )
            let config = AlarmManager.AlarmConfiguration<ShiftWakeAlarmMetadata>(
                countdownDuration: nil,
                schedule: .fixed(fireDate),
                attributes: attributes,
                stopIntent: nil,
                secondaryIntent: nil,
                sound: .default
            )
            do {
                _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: config)
                return true
            } catch {
                return false
            }
        }
        #endif
        return false
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
public struct ShiftWakeAlarmMetadata: AlarmMetadata {
    public init() {}
}
#endif
