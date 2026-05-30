import Foundation
import Observation
import Photos

@Observable
final class PhotoInclusionStore {
    static let shared = PhotoInclusionStore()

    // scheduleID → manually-included localIdentifier の集合
    private var inclusions: [String: Set<String>] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: "photoInclusions"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            inclusions = decoded.mapValues { Set($0) }
        }
    }

    func isIncluded(assetID: String, scheduleID: UUID) -> Bool {
        inclusions[scheduleID.uuidString]?.contains(assetID) ?? false
    }

    func include(assetIDs: Set<String>, scheduleID: UUID) {
        let key = scheduleID.uuidString
        var current = inclusions[key] ?? []
        current.formUnion(assetIDs)
        inclusions[key] = current
        save()
    }

    func remove(assetID: String, scheduleID: UUID) {
        let key = scheduleID.uuidString
        inclusions[key]?.remove(assetID)
        if inclusions[key]?.isEmpty == true { inclusions.removeValue(forKey: key) }
        save()
    }

    func includedIDs(for scheduleID: UUID) -> [String] {
        Array(inclusions[scheduleID.uuidString] ?? [])
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
        let encodable = inclusions.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: "photoInclusions")
        }
    }
}
