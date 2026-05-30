import Foundation
import Observation

@Observable final class MakeupClassStore {
    static let shared = MakeupClassStore()
    private init() {}

    var makeupClasses: [MakeupClass] = []

    func sync(makeupClasses: [MakeupClass]) {
        self.makeupClasses = makeupClasses
    }

    func makeupClasses(for scheduleID: UUID) -> [MakeupClass] {
        makeupClasses.filter { $0.scheduleID == scheduleID }
    }
}
