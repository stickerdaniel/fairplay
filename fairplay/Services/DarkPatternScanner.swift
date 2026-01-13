import Foundation

/// Progress events emitted during scanning
enum ScanProgressEvent: Sendable {
    case inputPrepared(html: String, originalSize: Int)
    case chunkStarted(size: Int)
    case chunkCompleted(size: Int, succeeded: Bool)
    case responseReceived(String)
}

protocol DarkPatternScannerProtocol: Sendable {
    func scan(
        html: String,
        onProgress: (@MainActor @Sendable (ScanProgressEvent) -> Void)?
    ) async throws -> [DarkPattern]
}

final class MockDarkPatternScanner: DarkPatternScannerProtocol, Sendable {
    func scan(
        html: String,
        onProgress: (@MainActor @Sendable (ScanProgressEvent) -> Void)? = nil
    ) async -> [DarkPattern] {
        // Simulate 2 second scan
        try? await Task.sleep(for: .seconds(2))

        // 50% chance of finding patterns
        let foundPatterns = Bool.random()
        print("[MockScanner] Scan completed - found patterns: \(foundPatterns)")

        if !foundPatterns {
            return []
        }

        // Return demo patterns
        var patterns: [DarkPattern] = []

        if let category = CategoryLoader.category(forId: "hidden_information") {
            patterns.append(DarkPattern(
                id: UUID(),
                category: category,
                title: "Hidden Reject Button",
                description: "The 'Reject All' button has low contrast and smaller text than 'Accept'",
                elementSelector: ".cookie-banner .reject-btn"
            ))
        }
        if let category = CategoryLoader.category(forId: "confirmshaming") {
            patterns.append(DarkPattern(
                id: UUID(),
                category: category,
                title: "Guilt Trip Text",
                description: "Double negative language makes it unclear how to decline",
                elementSelector: ".preferences-modal .opt-out"
            ))
        }
        if let category = CategoryLoader.category(forId: "preselected_options") {
            patterns.append(DarkPattern(
                id: UUID(),
                category: category,
                title: "Pre-checked Marketing",
                description: "Marketing consent checkbox is pre-selected by default",
                elementSelector: "#marketing-checkbox"
            ))
        }
        if let category = CategoryLoader.category(forId: "false_hierarchy") {
            patterns.append(DarkPattern(
                id: UUID(),
                category: category,
                title: "Misleading Button Colors",
                description: "Accept button is bright and prominent while decline is grayed out",
                elementSelector: ".consent-buttons"
            ))
        }

        return patterns
    }
}
