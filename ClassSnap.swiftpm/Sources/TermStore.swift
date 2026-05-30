import Foundation
import Observation

@Observable
final class TermStore {
    static let shared = TermStore()

    var terms: [AcademicTerm] = []

    var currentTerm: AcademicTerm? {
        terms.first { $0.isActive }
    }

    var hasAnyTerm: Bool { !terms.isEmpty }

    private init() {}

    func sync(terms: [AcademicTerm]) {
        self.terms = terms.sorted { $0.sortOrder < $1.sortOrder }
    }

    func term(forID id: UUID) -> AcademicTerm? {
        terms.first { $0.id == id }
    }
}
