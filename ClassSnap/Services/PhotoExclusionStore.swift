import Foundation
import Observation

@Observable
final class PhotoExclusionStore {
    static let shared = PhotoExclusionStore()

    // scheduleID → excluded localIdentifier の集合
    private var exclusions: [String: Set<String>] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: "photoExclusions"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            exclusions = decoded.mapValues { Set($0) }
        }
    }

    func isExcluded(assetID: String, scheduleID: UUID) -> Bool {
        exclusions[scheduleID.uuidString]?.contains(assetID) ?? false
    }

    func exclude(assetIDs: Set<String>, scheduleID: UUID) {
        let key = scheduleID.uuidString
        var current = exclusions[key] ?? []
        current.formUnion(assetIDs)
        exclusions[key] = current
        save()
    }

    func include(assetID: String, scheduleID: UUID) {
        let key = scheduleID.uuidString
        exclusions[key]?.remove(assetID)
        save()
    }

    private func save() {
        let encodable = exclusions.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: "photoExclusions")
        }
    }
}
