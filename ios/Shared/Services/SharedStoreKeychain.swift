import Foundation
import Security

extension SharedStore {

    public func exportWebCompatibleJSON(state: ShiftPayState) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    public struct BridgeWrapper: Codable {
        public var app: String?
        public var state: ShiftPayState?
        public var fullState: ShiftPayState?
    }

    public func importFromJSONString(_ jsonString: String) throws -> ShiftPayState {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw NSError(domain: "ShiftPay", code: 400, userInfo: [NSLocalizedDescriptionKey: "無效的文字編碼"])
        }
        let decoder = JSONDecoder()
        if let wrapper = try? decoder.decode(BridgeWrapper.self, from: data) {
            if let s = wrapper.state, (!s.shifts.isEmpty || !s.stamps.isEmpty) { return s }
            if let fs = wrapper.fullState, (!fs.shifts.isEmpty || !fs.stamps.isEmpty) { return fs }
        }
        return try decoder.decode(ShiftPayState.self, from: data)
    }

    internal func localStateFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("shiftpay_state_v3.json")
    }

    internal func activeAppGroupURL() -> URL? {
        for group in candidateAppGroups {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) { return url }
        }
        return nil
    }

    internal func writeKeychain(data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    internal func readKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
}
