import Foundation
import SwiftData

/// アプリ内に保存した写真1枚分のメタデータ。
/// 画像実体は Documents/SavedPhotos/<fileName> に JPEG で保存する。
@Model
final class SavedPhoto {
    var id: UUID
    var scheduleID: UUID
    /// 元の PHAsset localIdentifier（除外/手動追加との整合・重複判定に使用）
    var localIdentifier: String
    var creationDate: Date
    /// Documents/SavedPhotos 配下のファイル名（例: <uuid>.jpg）
    var fileName: String

    init(id: UUID = UUID(), scheduleID: UUID, localIdentifier: String,
         creationDate: Date, fileName: String) {
        self.id = id
        self.scheduleID = scheduleID
        self.localIdentifier = localIdentifier
        self.creationDate = creationDate
        self.fileName = fileName
    }
}
