import Foundation
import SwiftUI

@Observable
@MainActor
final class DarkPatternViewModel {
    var scanState: ScanState = .idle
    var patterns: [DarkPattern] = []
    var modifications: [UUID: PatternModification] = [:]
    var isSheetPresented = false

    // Debug properties
    private(set) var debugHTMLSent: String = ""
    private(set) var debugLLMResponse: String = ""
    private(set) var reasoning: String = ""
    private(set) var originalHTMLSize: Int = 0
    private(set) var sentHTMLSize: Int = 0
    private(set) var usedBackend: LLMBackend = .foundationModels
    private(set) var usedMLXModel: MLXModel? = nil
    private(set) var chunkAttempts: [ChunkAttempt] = []

    private let scanner: DarkPatternScannerProtocol
    private let modifier: PatternModifierProtocol
    private var currentPageHTML: String = ""

    init(
        scanner: DarkPatternScannerProtocol = MockDarkPatternScanner(),
        modifier: PatternModifierProtocol = MockPatternModifier()
    ) {
        self.scanner = scanner
        self.modifier = modifier
    }

    func scanPage(html: String) async {
        // Reset state for new page
        resetForNewPage()
        currentPageHTML = html
        scanState = .scanning

        // Capture which backend/model is being used for this scan
        usedBackend = LLMService.backend
        usedMLXModel = usedBackend == .mlx ? LLMService.mlxModel : nil

        do {
            let foundPatterns = try await scanner.scan(html: html)

            // Capture debug data from LLM scanner
            if let llmScanner = scanner as? DarkPatternLLMScanner {
                debugHTMLSent = llmScanner.lastHTMLSent
                debugLLMResponse = llmScanner.lastRawResponse
                reasoning = llmScanner.lastReasoning
                originalHTMLSize = html.count
                sentHTMLSize = llmScanner.lastHTMLSent.count
                chunkAttempts = llmScanner.chunkAttempts
            }

            patterns = foundPatterns

            if foundPatterns.isEmpty {
                scanState = .safe
            } else {
                scanState = .patternsFound
                // Initialize modifications for each pattern
                for pattern in foundPatterns {
                    modifications[pattern.id] = PatternModification(patternId: pattern.id, status: .pending)
                }
            }
        } catch {
            // Capture debug data even on error
            if let llmScanner = scanner as? DarkPatternLLMScanner {
                debugHTMLSent = llmScanner.lastHTMLSent
                debugLLMResponse = llmScanner.lastRawResponse
                reasoning = llmScanner.lastReasoning
                originalHTMLSize = html.count
                sentHTMLSize = llmScanner.lastHTMLSent.count
                chunkAttempts = llmScanner.chunkAttempts
            }

            scanState = .error(error.localizedDescription)
            print("[DarkPatternViewModel] Scan failed: \(error)")
        }
    }

    func togglePattern(_ pattern: DarkPattern) async {
        guard var modification = modifications[pattern.id] else { return }

        switch modification.status {
        case .pending, .failed:
            // Apply the modification
            await applyModification(for: pattern)

        case .applied:
            // Revert the modification
            await revertModification(for: pattern)

        case .applying:
            // Already in progress, ignore
            break
        }
    }

    func retryModification(for pattern: DarkPattern) async {
        await applyModification(for: pattern)
    }

    private func applyModification(for pattern: DarkPattern) async {
        guard var modification = modifications[pattern.id] else { return }

        // Store original HTML if not already stored
        if modification.originalHTML == nil {
            modification.originalHTML = currentPageHTML
        }

        modification.status = .applying
        modifications[pattern.id] = modification

        do {
            let modifiedHTML = try await modifier.modify(pattern: pattern, html: currentPageHTML)
            modification.status = .applied
            modification.appliedHTML = modifiedHTML
            modifications[pattern.id] = modification

            // In real implementation, inject the modified HTML back into the page
            print("Applied modification for: \(pattern.title)")

        } catch {
            modification.status = .failed(error.localizedDescription)
            modifications[pattern.id] = modification
            print("Failed to apply modification: \(error)")
        }
    }

    private func revertModification(for pattern: DarkPattern) async {
        guard var modification = modifications[pattern.id],
              let originalHTML = modification.originalHTML else { return }

        modification.status = .applying
        modifications[pattern.id] = modification

        do {
            _ = try await modifier.revert(pattern: pattern, originalHTML: originalHTML)
            modification.status = .pending
            modification.appliedHTML = nil
            modifications[pattern.id] = modification

            print("Reverted modification for: \(pattern.title)")

        } catch {
            // If revert fails, keep it as applied
            modification.status = .applied
            modifications[pattern.id] = modification
            print("Failed to revert modification: \(error)")
        }
    }

    func resetForNewPage() {
        scanState = .idle
        patterns = []
        modifications = [:]
        currentPageHTML = ""
        debugHTMLSent = ""
        debugLLMResponse = ""
        reasoning = ""
        originalHTMLSize = 0
        sentHTMLSize = 0
        usedBackend = .foundationModels
        usedMLXModel = nil
        chunkAttempts = []
    }

    // Computed property for applied count (useful for UI)
    var appliedCount: Int {
        modifications.values.filter { $0.status == .applied }.count
    }

    var hasAppliedModifications: Bool {
        appliedCount > 0
    }
}
