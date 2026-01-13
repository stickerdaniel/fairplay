import Foundation

struct DarkPattern: Identifiable, Equatable {
    let id: UUID
    let category: DarkPatternCategory
    let title: String
    let description: String
    let elementSelector: String

    static func == (lhs: DarkPattern, rhs: DarkPattern) -> Bool {
        lhs.id == rhs.id
    }
}

struct PatternModification: Identifiable {
    let id: UUID
    let patternId: UUID
    var status: Status
    var appliedJavaScript: String?
    var originalHTML: String?
    var modifierLogs: String?  // Stores debug info from the modifier

    enum Status: Equatable {
        case pending
        case applying
        case applied
        case failed(String)

        static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .pending), (.applying, .applying), (.applied, .applied):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    init(patternId: UUID, status: Status = .pending) {
        self.id = UUID()
        self.patternId = patternId
        self.status = status
    }
}

enum ScanState: Equatable {
    case idle
    case scanning
    case safe
    case patternsFound
    case error(String)
    case excluded
}
