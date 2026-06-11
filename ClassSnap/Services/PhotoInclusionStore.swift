import Foundation
import Observation
import Photos

@Observable
final class PhotoInclusionStore {
    static let shared = PhotoInclusionStore()

    // scheduleID → { assetLocalIdentifier → sessionOverride }
    // sessionOverride: 0 = auto-assign by shooting date, N > 0 = forced session number
    // アルバム読み込みは Task.detached からも読むため、lock で保護する
    private var inclusions: [String: [String: Int]] = [:]
    private let lock = NSLock()

    /// 変更のたびにインクリメントされる。Viewが onChange で監視してアルバムを再読み込みする。
    private(set) var version = 0

    private init() {
        if let data = UserDefaults.standard.data(forKey: "photoInclusions") {
            // Try new format first
            if let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
                inclusions = decoded
            } else if let legacy = try? JSONDecoder().decode([String: [String]].self, from: data) {
                // Migrate from old format (no session override → auto = 0)
                // 重複IDが混入していてもクラッシュしないよう uniquingKeysWith で防御
                inclusions = legacy.mapValues { ids in
                    Dictionary(ids.map { ($0, 0) }, uniquingKeysWith: { first, _ in first })
                }
                save()
            }
        }
    }

    func isIncluded(assetID: String, scheduleID: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return inclusions[scheduleID.uuidString]?[assetID] != nil
    }

    /// Returns the session override for a manually-included asset.
    /// nil = asset not in inclusion store; 0 = auto; N > 0 = forced session number
    func sessionOverride(for assetID: String, scheduleID: UUID) -> Int? {
        lock.lock(); defer { lock.unlock() }
        return inclusions[scheduleID.uuidString]?[assetID]
    }

    func include(assetIDs: Set<String>, scheduleID: UUID, sessionOverride: Int) {
        let key = scheduleID.uuidString
        lock.lock()
        var current = inclusions[key] ?? [:]
        for id in assetIDs { current[id] = sessionOverride }
        inclusions[key] = current
        lock.unlock()
        save()
    }

    func remove(assetID: String, scheduleID: UUID) {
        let key = scheduleID.uuidString
        lock.lock()
        let removed = inclusions[key]?.removeValue(forKey: assetID) != nil
        if inclusions[key]?.isEmpty == true { inclusions.removeValue(forKey: key) }
        lock.unlock()
        // 手動追加でない写真の除外時に version を進めると不要な全件再スキャンが走るため、
        // 実際に削除した場合のみ保存・通知する
        if removed { save() }
    }

    func includedIDs(for scheduleID: UUID) -> [String] {
        lock.lock(); defer { lock.unlock() }
        guard let keys = inclusions[scheduleID.uuidString]?.keys else { return [] }
        return Array(keys)
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
        version &+= 1
        if let data = try? JSONEncoder().encode(inclusions) {
            UserDefaults.standard.set(data, forKey: "photoInclusions")
        }
    }
}
