import Foundation
import Observation
import SwiftUI

struct TestRange: Identifiable, Codable {
    var id: UUID
    var label: String
    /// 開始授業回の代表日（最早撮影日）。補講追加・初回日変更の影響を受けない。
    var startDate: Date
    /// 終了授業回の代表日（最早撮影日）。
    var endDate: Date
    var colorName: String

    // MARK: - Codable（旧形式 startSession/endSession からの移行）

    private enum CodingKeys: String, CodingKey {
        case id, label, colorName
        case startDate, endDate
        case legacyStart = "startSession"
        case legacyEnd   = "endSession"
    }

    init(id: UUID = UUID(), label: String, startDate: Date, endDate: Date, colorName: String = "orange") {
        self.id        = id
        self.label     = label
        self.startDate = startDate
        self.endDate   = endDate
        self.colorName = colorName
    }

    init(from decoder: Decoder) throws {
        let c     = try decoder.container(keyedBy: CodingKeys.self)
        id        = try  c.decode(UUID.self,   forKey: .id)
        label     = try  c.decode(String.self, forKey: .label)
        colorName = (try? c.decode(String.self, forKey: .colorName)) ?? "orange"
        if let sd = try? c.decode(Date.self, forKey: .startDate),
           let ed = try? c.decode(Date.self, forKey: .endDate) {
            startDate = sd
            endDate   = ed
        } else {
            // 旧形式は授業回番号しか持たず、スケジュールなしでは日付に変換できない。
            // sentinel 値（start > end）を入れてマッチ不能にし、再設定を促す。
            startDate = .distantFuture
            endDate   = .distantPast
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(label,     forKey: .label)
        try c.encode(colorName, forKey: .colorName)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(endDate,   forKey: .endDate)
    }

    // MARK: - Matching

    /// この授業回がテスト範囲に含まれるか（授業回の最早撮影日で判定）
    func contains(session: SessionAlbum) -> Bool {
        guard let sessionDate = session.assets.compactMap(\.creationDate).min() else { return false }
        let cal   = Calendar.current
        let day   = cal.startOfDay(for: sessionDate)
        let start = cal.startOfDay(for: startDate)
        let end   = cal.startOfDay(for: endDate)
        return day >= start && day <= end
    }

    /// 旧データ（マイグレーション前）かどうか（start > end になっている）
    var needsMigration: Bool { startDate > endDate }

    // MARK: - Display

    var displayRange: String {
        if needsMigration { return "範囲を再設定してください" }
        let fmt = AppDateFormatters.mdJP
        return "\(fmt.string(from: startDate))〜\(fmt.string(from: endDate))"
    }

    var color: Color {
        switch colorName {
        case "red":    return .red
        case "orange": return .orange
        case "blue":   return .blue
        case "purple": return .purple
        case "teal":   return .teal
        default:       return .orange
        }
    }

    static let colorOptions: [(name: String, color: Color)] = [
        ("orange", .orange),
        ("red",    .red),
        ("blue",   .blue),
        ("purple", .purple),
        ("teal",   .teal),
    ]
}

@Observable
final class TestRangeStore {
    static let shared = TestRangeStore()
    private var rangesBySchedule: [String: [TestRange]] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: "testRanges"),
           let decoded = try? JSONDecoder().decode([String: [TestRange]].self, from: data) {
            rangesBySchedule = decoded
        }
    }

    func ranges(for scheduleID: UUID) -> [TestRange] {
        rangesBySchedule[scheduleID.uuidString] ?? []
    }

    func rangesContaining(session: SessionAlbum, scheduleID: UUID) -> [TestRange] {
        ranges(for: scheduleID).filter { $0.contains(session: session) }
    }

    func add(_ range: TestRange, for scheduleID: UUID) {
        let key = scheduleID.uuidString
        var list = rangesBySchedule[key] ?? []
        list.append(range)
        rangesBySchedule[key] = list
        save()
    }

    func update(_ range: TestRange, for scheduleID: UUID) {
        let key = scheduleID.uuidString
        guard let idx = rangesBySchedule[key]?.firstIndex(where: { $0.id == range.id }) else { return }
        rangesBySchedule[key]?[idx] = range
        save()
    }

    func remove(id: UUID, for scheduleID: UUID) {
        let key = scheduleID.uuidString
        rangesBySchedule[key]?.removeAll { $0.id == id }
        if rangesBySchedule[key]?.isEmpty == true { rangesBySchedule.removeValue(forKey: key) }
        save()
    }

    /// 授業削除時の掃除。この授業のテスト範囲をすべて削除する
    func removeAll(forScheduleID scheduleID: UUID) {
        guard rangesBySchedule.removeValue(forKey: scheduleID.uuidString) != nil else { return }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rangesBySchedule) {
            UserDefaults.standard.set(data, forKey: "testRanges")
        }
    }
}
