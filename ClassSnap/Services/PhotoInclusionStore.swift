import Foundation
import Observation
import Photos

@Observable
final class PhotoInclusionStore {
    static let shared = PhotoInclusionStore()

    // scheduleID → { assetLocalIdentifier → sessionOverride }
    // sessionOverride: 0 = auto-assign by shooting date, N > 0 = forced session number
    private var inclusions: [String: [String: Int]] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: "photoInclusions") {
            // Try new format first
            if let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
                inclusions = decoded
            } else if let legacy = try? JSONDecoder().decode([String: [String]].self, from: data) {
                // Migrate from old format (no session override → auto = 0)
                inclusions = legacy.mapValues { ids in
                    Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) })
                }
                save()
            }
        }
    }

    func isIncluded(assetID: String, scheduleID: UUID) -> Bool {
        inclusions[scheduleID.uuidString]?[assetID] != nil
    }

    /// Returns the session override for a manually-included asset.
    /// nil = asset not in inclusion store; 0 = auto; N > 0 = forced session number
    func sessionOverride(for assetID: String, scheduleID: UUID) -> Int? {
        inclusions[scheduleID.uuidString]?[assetID]
    }

    func include(assetIDs: Set<String>, scheduleID: UUID, sessionOverride: Int) {
        let key = scheduleID.uuidString
        var current = inclusions[key] ?? [:]
        for id in assetIDs { current[id] = sessionOverride }
        inclusions[key] = current
        save()
    }

    func remove(assetID: String, scheduleID: UUID) {
        let key = scheduleID.uuidString
        inclusions[key]?.removeValue(forKey: assetID)
        if inclusions[key]?.isEmpty == true { inclusions.removeValue(forKey: key) }
        save()
    }

    func includedIDs(for scheduleID: UUID) -> [String] {
        Array(inclusions[scheduleID.uuidString]?.keys ?? [].makeIterator())
    }

    func fetchAssets(for scheduleID: UUID) -> [PHAsset] {
        let ids = includedIDs(for: scheduleID)
        guard !ids.isEmpty else { return [] }
        var result: [PHAsset] = []
        PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            .enumerateObjects { asset, _, _ in result.append(asset) }
        return result.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(inclusions) {
            UserDefaults.standard.set(data, forKey: "photoInclusions")
        }
    }
}
