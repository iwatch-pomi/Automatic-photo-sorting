import Foundation
import Observation

@Observable
final class SessionTitleStore {
    static let shared = SessionTitleStore()

    private var titles: [String: String] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: "sessionTitles"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            titles = decoded
        }
    }

    func title(for sessionID: String) -> String? {
        guard let t = titles[sessionID], !t.isEmpty else { return nil }
        return t
    }

    /// 日付ベースの新キーを優先して引き、無ければ旧キー（回番号ベース）から
    /// 読み替えて新キーへ移行する。回番号ズレでタイトルが別の回に付く問題への対策。
    func title(primaryKey: String, legacyKey: String) -> String? {
        if let t = title(for: primaryKey) { return t }
        guard let legacy = title(for: legacyKey) else { return nil }
        titles[primaryKey] = legacy
        titles.removeValue(forKey: legacyKey)
        save()
        return legacy
    }

    func setTitle(_ title: String, for sessionID: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            titles.removeValue(forKey: sessionID)
        } else {
            titles[sessionID] = trimmed
        }
        save()
    }

    func removeTitle(for sessionID: String) {
        titles.removeValue(forKey: sessionID)
        save()
    }

    /// 授業削除時の掃除。この授業のタイトルをすべて削除する
    /// （キーは新旧とも scheduleID.uuidString が接頭辞）。
    func removeTitles(forScheduleID scheduleID: UUID) {
        let prefix = scheduleID.uuidString
        let before = titles.count
        titles = titles.filter { !$0.key.hasPrefix(prefix) }
        if titles.count != before { save() }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(titles) {
            UserDefaults.standard.set(data, forKey: "sessionTitles")
        }
    }
}
