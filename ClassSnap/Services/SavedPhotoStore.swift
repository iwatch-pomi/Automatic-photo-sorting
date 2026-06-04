import Foundation
import SwiftData
import Observation
import UIKit

/// アプリ内に保存した写真（SavedPhoto）の管理。
/// 画像実体は Documents/SavedPhotos/ に JPEG で保存し、メタデータは SwiftData に持つ。
@MainActor
@Observable
final class SavedPhotoStore {
    static let shared = SavedPhotoStore()
    private init() {}

    private var context: ModelContext?

    /// 保存処理が進行中の scheduleID（多重実行ガード）
    private var inFlight: Set<UUID> = []

    /// 変更通知用（追加/削除でインクリメント）。View が onChange で監視可能。
    private(set) var version = 0

    /// 保存先ディレクトリ
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("SavedPhotos", isDirectory: true)
    }

    /// ModelContext を注入（アプリ起動時に一度）。同時に孤児整理を行う。
    func configure(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        ensureDirectoryExists()
        reconcile()
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: Self.directory,
                                                 withIntermediateDirectories: true)
    }

    func fileURL(for photo: SavedPhoto) -> URL {
        Self.directory.appendingPathComponent(photo.fileName)
    }

    // MARK: - Query

    func savedPhotos(for scheduleID: UUID) -> [SavedPhoto] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<SavedPhoto>(
            predicate: #Predicate { $0.scheduleID == scheduleID },
            sortBy: [SortDescriptor(\.creationDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func savedLocalIdentifiers(for scheduleID: UUID) -> Set<String> {
        Set(savedPhotos(for: scheduleID).map { $0.localIdentifier })
    }

    func hasSavedPhotos(for scheduleID: UUID) -> Bool {
        !savedPhotos(for: scheduleID).isEmpty
    }

    /// scheduleID の保存写真の合計バイト数（ファイルサイズ）
    func totalBytes(for scheduleID: UUID) -> Int64 {
        var total: Int64 = 0
        for photo in savedPhotos(for: scheduleID) {
            let url = fileURL(for: photo)
            if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    // MARK: - Save / Delete

    func isInFlight(_ scheduleID: UUID) -> Bool { inFlight.contains(scheduleID) }
    func beginInFlight(_ scheduleID: UUID) { inFlight.insert(scheduleID) }
    func endInFlight(_ scheduleID: UUID) { inFlight.remove(scheduleID) }

    /// JPEG データを保存し SavedPhoto を作成。既存（同 localIdentifier）はスキップ。
    /// ディスク書き込みはバックグラウンドで行い、メインスレッドをブロックしない。
    @discardableResult
    func save(imageData: Data, localIdentifier: String, creationDate: Date,
              scheduleID: UUID) async -> Bool {
        guard context != nil else { return false }
        // 重複ガード（書き込み前）
        if savedLocalIdentifiers(for: scheduleID).contains(localIdentifier) { return false }

        ensureDirectoryExists()
        let fileName = "\(UUID().uuidString).jpg"
        let url = Self.directory.appendingPathComponent(fileName)

        // 書き込みはメインスレッド外で実行
        let wrote = await Task.detached(priority: .background) {
            do { try imageData.write(to: url, options: .atomic); return true }
            catch { return false }
        }.value
        guard wrote else { return false }

        // await 中に別タスクが同じ写真を保存していないか再確認
        guard let context, !savedLocalIdentifiers(for: scheduleID).contains(localIdentifier) else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        let record = SavedPhoto(scheduleID: scheduleID, localIdentifier: localIdentifier,
                                creationDate: creationDate, fileName: fileName)
        context.insert(record)
        try? context.save()
        // version はここでは更新しない。バッチ保存の最後に notifyChange() で一括通知し、
        // 1枚ごとのアルバム再読み込みループを防ぐ。
        return true
    }

    /// 保存内容の変更を View に通知（バッチ保存の完了後などに一度だけ呼ぶ）
    func notifyChange() {
        version &+= 1
    }

    /// 指定授業の保存写真のうち、`matches` に一致しなくなったものを削除する。
    /// `keepIdentifiers`（手動追加など）に含まれる写真は条件に関わらず残す。
    /// 時間割（コマ・時刻・曜日など）の変更時に呼び、古いマッチ写真を整理する。
    func deleteStaleMatches(for scheduleID: UUID,
                            keepIdentifiers: Set<String>,
                            matches: (Date) -> Bool) {
        guard let context else { return }
        let photos = savedPhotos(for: scheduleID)
        var changed = false
        for photo in photos {
            if keepIdentifiers.contains(photo.localIdentifier) { continue }
            if matches(photo.creationDate) { continue }
            try? FileManager.default.removeItem(at: fileURL(for: photo))
            context.delete(photo)
            changed = true
        }
        if changed {
            try? context.save()
            version &+= 1
        }
    }

    /// scheduleID の保存写真（実体＋レコード）をすべて削除
    func deleteAll(for scheduleID: UUID) {
        guard let context else { return }
        let photos = savedPhotos(for: scheduleID)
        guard !photos.isEmpty else { return }
        for photo in photos {
            try? FileManager.default.removeItem(at: fileURL(for: photo))
            context.delete(photo)
        }
        try? context.save()
        version &+= 1
    }

    // MARK: - Reconcile（孤児整理）

    /// レコードの無いファイル / ファイルの無いレコードを掃除する。
    func reconcile() {
        guard let context else { return }
        let all = (try? context.fetch(FetchDescriptor<SavedPhoto>())) ?? []

        // ファイル欠損レコードを削除
        var validFileNames: Set<String> = []
        var changed = false
        for record in all {
            let url = fileURL(for: record)
            if FileManager.default.fileExists(atPath: url.path) {
                validFileNames.insert(record.fileName)
            } else {
                context.delete(record)
                changed = true
            }
        }
        if changed { try? context.save() }

        // レコードの無いファイルを削除
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: Self.directory,
                                                   includingPropertiesForKeys: nil) {
            for file in files where !validFileNames.contains(file.lastPathComponent) {
                try? fm.removeItem(at: file)
            }
        }
    }
}
