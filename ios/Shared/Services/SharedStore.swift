import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class SharedStore: @unchecked Sendable {
    public static let shared = SharedStore()

    internal let stateAccountKey = "shiftpay.v3.fullstate"
    internal let widgetAccountKey = "shiftpay.v3.widgetpayload"
    internal let keychainService = "com.mrhaibaoseal.shiftpay.shared"
    /// FlareStore 憑證只開放 group.81c139ae9a27a7f8.1～5，放最前面才寫得進去；
    /// 練壯（workout）也從這裡讀班表來排運動時間。
    internal let candidateAppGroups = [
        "group.81c139ae9a27a7f8.1",
        "group.com.mrhaibaoseal.shiftpay",
        "group.com.shiftpay.shared"
    ]

    private init() {}

    public func loadState() -> ShiftPayState {
        if let docData = try? Data(contentsOf: localStateFileURL()),
           let decoded = try? JSONDecoder().decode(ShiftPayState.self, from: docData) {
            return decoded
        }
        if let kcData = readKeychain(account: stateAccountKey),
           let decoded = try? JSONDecoder().decode(ShiftPayState.self, from: kcData) {
            return decoded
        }
        if let groupURL = activeAppGroupURL()?.appendingPathComponent("shiftpay_state.json"),
           let groupData = try? Data(contentsOf: groupURL),
           let decoded = try? JSONDecoder().decode(ShiftPayState.self, from: groupData) {
            return decoded
        }
        if let udData = UserDefaults.standard.data(forKey: ShiftPayConstants.legacyStorageKey),
           let decoded = try? JSONDecoder().decode(ShiftPayState.self, from: udData) {
            return decoded
        }
        return ShiftPayState()
    }

    public func saveState(_ state: ShiftPayState, viewYear: Int? = nil, viewMonth: Int? = nil) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(state) else { return }

        try? data.write(to: localStateFileURL(), options: .atomic)
        UserDefaults.standard.set(data, forKey: ShiftPayConstants.legacyStorageKey)

        if let groupURL = activeAppGroupURL()?.appendingPathComponent("shiftpay_state.json") {
            try? data.write(to: groupURL, options: .atomic)
        }
        writeKeychain(data: data, account: stateAccountKey)

        let payload = PayrollEngine.buildWidgetPayload(state: state, viewYear: viewYear, viewMonth: viewMonth)
        if let payloadData = try? encoder.encode(payload) {
            writeKeychain(data: payloadData, account: widgetAccountKey)
            if let groupPayloadURL = activeAppGroupURL()?.appendingPathComponent("shift_data.json") {
                try? payloadData.write(to: groupPayloadURL, options: .atomic)
            }
        }
        reloadAllWidgets()
    }

    /// 把目前的班表寫一份到 App Group，讓其他 App（練壯）讀得到。
    /// 只寫 shiftpay_state.json，不動本機存檔與 Keychain。
    public func mirrorStateToAppGroup(_ state: ShiftPayState) {
        guard let groupURL = activeAppGroupURL()?.appendingPathComponent("shiftpay_state.json"),
              let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: groupURL, options: .atomic)
    }

    public func loadWidgetPayload() -> WidgetSyncPayload {
        let state = loadState()
        if !state.shifts.isEmpty {
            return PayrollEngine.buildWidgetPayload(state: state)
        }
        if let kcData = readKeychain(account: widgetAccountKey),
           let payload = try? JSONDecoder().decode(WidgetSyncPayload.self, from: kcData) {
            return payload
        }
        return PayrollEngine.buildWidgetPayload(state: state)
    }

    @discardableResult
    public func addQuickOvertimeFromWidget(minutes: Int) -> Bool {
        var state = loadState()
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let todayKey = PayrollEngine.dateKey(
            year: cal.component(.year, from: now),
            month: cal.component(.month, from: now),
            day: cal.component(.day, from: now)
        )

        if var todayShift = state.shifts[todayKey] {
            todayShift.otMin = max(0, todayShift.otMin + minutes)
            state.shifts[todayKey] = todayShift
            saveState(state)
            return true
        }

        let stamp = state.stamps.first ?? ShiftStamp.defaultStamps[0]
        state.shifts[todayKey] = ShiftRecord(
            name: stamp.name,
            color: stamp.color,
            start: stamp.start,
            end: stamp.end,
            breakMin: stamp.breakMin,
            stampId: stamp.id,
            otMin: max(0, minutes),
            status: .normal,
            leaveType: .late,
            note: "桌面小工具快速加班 +\(minutes)m"
        )
        saveState(state)
        return true
    }

    public func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
