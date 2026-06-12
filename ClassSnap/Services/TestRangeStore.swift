import Foundation
import Observation
import SwiftUI

struct TestRange: Identifiable, Codable {
    var id: UUID
    var label: String        // "中間テスト", "期末テスト" など
    var startSession: Int    // 第N回から
    var endSession: Int      // 第M回まで
    var colorName: String    // "red" | "orange" | "blue" | "purple" | "teal"

    init(label: String, startSession: Int, endSession: Int, colorName: String = "orange") {
        self.id = UUID()
        self.label = label
        self.startSession = startSession
        self.endSession = endSession
        self.colorName = colorName
    }

    func contains(_ sessionNumber: Int) -> Bool {
        sessionNumber >= startSession && sessionNumber <= endSession
    }

    var displayRange: String { "第\(startSession)回〜第\(endSession)回" }

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

    func rangesContaining(session: Int, scheduleID: UUID) -> [TestRange] {
        ranges(for: scheduleID).filter { $0.contains(session) }
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
