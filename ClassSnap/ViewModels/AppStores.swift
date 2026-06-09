import Foundation
import SwiftData

/// 3つのドメインストア（授業・学期・補講）を束ねる軽量コンテナ。
/// ClassSnapApp で1度だけ生成し、各画面へ明示的に引き渡す。
/// 各ストアは @Observable なので、View 側で `stores.schedule.schedules` のように
/// 参照すれば該当プロパティの変更が自動で追跡される。
struct AppStores {
    let schedule: ScheduleStore
    let term: TermStore
    let makeup: MakeupStore

    @MainActor
    init(modelContext: ModelContext) {
        let scheduleStore = ScheduleStore(modelContext: modelContext)
        let termStore = TermStore(modelContext: modelContext)
        let makeupStore = MakeupStore(modelContext: modelContext)

        // 相互参照を配線（学期絞り込み・補講削除・termIDs クリアのため）
        scheduleStore.termStore = termStore
        scheduleStore.makeupStore = makeupStore
        termStore.scheduleStore = scheduleStore

        self.schedule = scheduleStore
        self.term = termStore
        self.makeup = makeupStore
    }
}

extension ModelContext {
    /// 変更を保存する。失敗を握りつぶす `try? save()` の代替。
    /// 失敗時は DEBUG ではアサート、本番ではログに残す。保存成否を返す。
    @discardableResult
    func saveChanges(_ caller: String = #function) -> Bool {
        do {
            try save()
            return true
        } catch {
            #if DEBUG
            assertionFailure("ModelContext.save() failed in \(caller): \(error)")
            #else
            print("⚠️ ModelContext.save() failed in \(caller): \(error)")
            #endif
            return false
        }
    }
}
