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

    private func save() {
        if let data = try? JSONEncoder().encode(titles) {
            UserDefaults.standard.set(data, forKey: "sessionTitles")
        }
    }
}
