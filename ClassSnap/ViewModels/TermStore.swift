import Foundation
import SwiftData
import Observation

/// 学期プリセット。データ生成は TermStore.applyTermPreset(_:) が担う。
enum TermPreset { case semesterJP, quarterJP }

/// 学期（AcademicTerm）の単一情報源。CRUD・プリセット・現在学期・選択学期を担当する。
/// 旧 TimetableViewModel から term 関連の責務を分離したもの。
@MainActor
@Observable
final class TermStore {
    private let modelContext: ModelContext

    /// 学期削除時の termIDs クリア用。AppStores が注入。
    @ObservationIgnored weak var scheduleStore: ScheduleStore?

    var terms: [AcademicTerm] = []
    var selectedTermID: UUID? = nil
    var errorMessage: String?

    /// 現在学期の自動選択は最初に学期が見つかった1回だけ行う。毎回行うと、
    /// ユーザーが明示的に「全期間」（nil）を選んだ後の学期CRUDで選択が勝手に戻る。
    @ObservationIgnored private var didAutoSelectTerm = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchTerms()
    }

    /// 現在進行中の学期
    var currentTerm: AcademicTerm? { terms.first { $0.isActive } }

    /// ID から学期を引く
    func term(forID id: UUID) -> AcademicTerm? { terms.first { $0.id == id } }

    // MARK: - CRUD

    func fetchTerms() {
        let descriptor = FetchDescriptor<AcademicTerm>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        do {
            terms = try modelContext.fetch(descriptor)
            if selectedTermID == nil, !didAutoSelectTerm, let current = currentTerm {
                selectedTermID = current.id
                didAutoSelectTerm = true
            }
        } catch {
            errorMessage = "学期の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func addTerm(name: String, startDate: Date, endDate: Date) {
        let order = terms.count
        let term = AcademicTerm(name: name, startDate: startDate, endDate: endDate, sortOrder: order)
        modelContext.insert(term)
        modelContext.saveChanges()
        fetchTerms()
    }

    func updateTerm(_ term: AcademicTerm, name: String, startDate: Date, endDate: Date) {
        term.name = name
        term.startDate = startDate
        term.endDate = endDate
        modelContext.saveChanges()
        fetchTerms()
    }

    func deleteTerm(_ term: AcademicTerm) {
        scheduleStore?.removeTermID(term.id)
        modelContext.delete(term)
        // 選択中の学期を削除した場合は選択を解除し、fetchTerms で現在の学期を選び直す
        if selectedTermID == term.id { selectedTermID = nil }
        modelContext.saveChanges()
        fetchTerms()
        scheduleStore?.fetchSchedules()
    }

    func deleteAllTerms() {
        terms.forEach { modelContext.delete($0) }
        scheduleStore?.clearAllTermIDs()
        selectedTermID = nil
        modelContext.saveChanges()
        fetchTerms()
        scheduleStore?.fetchSchedules()
    }

    /// プリセットの学期一式を作成する（既存学期は削除）。ビジネスロジックは View ではなくここに集約。
    func applyTermPreset(_ preset: TermPreset) {
        deleteAllTerms()
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let specs: [(String, DateComponents, DateComponents)]
        switch preset {
        case .semesterJP:
            specs = [
                ("前期", DateComponents(year: year, month: 4, day: 1),
                         DateComponents(year: year, month: 9, day: 30)),
                ("後期", DateComponents(year: year, month: 10, day: 1),
                         DateComponents(year: year + 1, month: 3, day: 31)),
            ]
        case .quarterJP:
            specs = [
                ("1T", DateComponents(year: year, month: 4, day: 1),
                       DateComponents(year: year, month: 6, day: 30)),
                ("2T", DateComponents(year: year, month: 7, day: 1),
                       DateComponents(year: year, month: 9, day: 30)),
                ("3T", DateComponents(year: year, month: 10, day: 1),
                       DateComponents(year: year, month: 12, day: 31)),
                ("4T", DateComponents(year: year + 1, month: 1, day: 1),
                       DateComponents(year: year + 1, month: 3, day: 31)),
            ]
        }
        for (i, (name, startDC, endDC)) in specs.enumerated() {
            guard let start = cal.date(from: startDC), let end = cal.date(from: endDC) else { continue }
            modelContext.insert(AcademicTerm(name: name, startDate: start, endDate: end, sortOrder: i))
        }
        modelContext.saveChanges()
        fetchTerms()
    }
}
