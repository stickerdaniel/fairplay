import Foundation

protocol PatternModifierProtocol: Sendable {
    func modify(pattern: DarkPattern, html: String) async throws -> String
    func revert(pattern: DarkPattern, originalHTML: String) async throws -> String
}

final class MockPatternModifier: PatternModifierProtocol, Sendable {
    enum ModificationError: Error, LocalizedError {
        case generationFailed

        var errorDescription: String? {
            switch self {
            case .generationFailed:
                return "Failed to generate modification"
            }
        }
    }

    func modify(pattern: DarkPattern, html: String) async throws -> String {
        // Simulate 1-3 second modification time
        try await Task.sleep(for: .seconds(Double.random(in: 1...3)))

        // 10% chance of failure for testing retry functionality
        if Int.random(in: 1...10) == 1 {
            throw ModificationError.generationFailed
        }

        // Return mock modified HTML
        // In real implementation, this would be the LLM-generated fix
        return "<!-- FairPlay Modified: \(pattern.category.name) -->\n\(html)"
    }

    func revert(pattern: DarkPattern, originalHTML: String) async throws -> String {
        // Simulate quick revert
        try await Task.sleep(for: .milliseconds(500))
        return originalHTML
    }
}
