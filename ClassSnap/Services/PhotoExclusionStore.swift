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
        refreshTotalCount()
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

    /// 除外件数の合計（複数スケジュール間で同じ写真を1枚としてカウント、Photos ライブラリに実際に存在するもののみ）。
    /// PHAsset の同期フェッチを View の body 評価ごとに走らせないよう、変更時に非同期で再計算してキャッシュする。
    private(set) var totalCount: Int = 0

    private func refreshTotalCount() {
        let allIDs = Set(exclusions.values.flatMap { $0 })
        guard !allIDs.isEmpty else {
            totalCount = 0
            return
        }
        Task.detached(priority: .utility) {
            var count = 0
            PHAsset.fetchAssets(withLocalIdentifiers: Array(allIDs), options: nil)
                .enumerateObjects { _, _, _ in count += 1 }
            await MainActor.run { [count] in self.totalCount = count }
        }
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

    /// 授業削除時の掃除。この授業の除外設定をすべて削除する
    func removeAll(forScheduleID scheduleID: UUID) {
        guard exclusions.removeValue(forKey: scheduleID.uuidString) != nil else { return }
        save()
    }

    private func save() {
        let encodable = exclusions.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: "photoExclusions")
        }
        refreshTotalCount()
    }
}
