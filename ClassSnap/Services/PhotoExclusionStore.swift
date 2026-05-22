import Foundation
import Observation
import Photos

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
        if exclusions[key]?.isEmpty == true { exclusions.removeValue(forKey: key) }
        save()
    }

    /// 除外件数の合計
    var totalCount: Int {
        exclusions.values.reduce(0) { $0 + $1.count }
    }

    /// scheduleID ごとの除外 assetID 一覧
    func excludedIDs(for scheduleID: UUID) -> [String] {
        Array(exclusions[scheduleID.uuidString] ?? [])
    }

    /// 除外写真がある scheduleID の一覧
    var scheduleIDsWithExclusions: [UUID] {
        exclusions.compactMap { key, ids in
            ids.isEmpty ? nil : UUID(uuidString: key)
        }
    }

    /// localIdentifier 配列から PHAsset を同期取得
    func fetchAssets(for scheduleID: UUID) -> [PHAsset] {
        let ids = excludedIDs(for: scheduleID)
        guard !ids.isEmpty else { return [] }
        var result: [PHAsset] = []
        PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            .enumerateObjects { asset, _, _ in result.append(asset) }
        return result.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    private func save() {
        let encodable = exclusions.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: "photoExclusions")
        }
    }
}
