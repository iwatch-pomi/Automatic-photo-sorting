import SwiftUI

/// 授業編集画面。実体は ClassFormView に統合済み（schedule 非nil で編集モード）。
struct EditClassView: View {
    var viewModel: TimetableViewModel
    let schedule: ClassSchedule

    var body: some View { ClassFormView(viewModel: viewModel, schedule: schedule) }
}
