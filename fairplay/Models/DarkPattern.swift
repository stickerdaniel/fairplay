import Foundation

struct DarkPattern: Identifiable, Equatable {
    let id: UUID
    let type: PatternType
    let title: String
    let description: String
    let elementSelector: String

    enum PatternType: String, CaseIterable {
        case hiddenDecline = "Hidden Decline"
        case confusingLanguage = "Confusing Language"
        case visualManipulation = "Visual Manipulation"
        case forcedAction = "Forced Action"
        case preselectedOptions = "Preselected Options"
    }

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
