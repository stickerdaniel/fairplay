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
    private var originalPageHTML: String = ""  // Pristine HTML before any patches

    // Callbacks for WebView interaction (set by ContentView)
    var executeJavaScript: ((String) async throws -> Void)?
    var setPageHTML: ((String) async throws -> Void)?

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
        originalPageHTML = html  // Cache for revert
        scanState = .scanning
        originalHTMLSize = html.count

        // Capture which backend/model is being used for this scan
        usedBackend = LLMService.backend
        usedMLXModel = usedBackend == .mlx ? LLMService.mlxModel : nil

        do {
            let foundPatterns = try await scanner.scan(html: html) { [weak self] event in
                guard let self else { return }
                switch event {
                case .inputPrepared(let sentHtml, let originalSize):
                    self.debugHTMLSent = sentHtml
                    self.originalHTMLSize = originalSize
                    self.sentHTMLSize = sentHtml.count

                case .chunkStarted(let size):
                    // Add new attempt with running status
                    self.chunkAttempts.append(ChunkAttempt(size: size, status: .running))

                case .chunkCompleted(let size, let succeeded):
                    // Update the existing attempt's status
                    if let index = self.chunkAttempts.lastIndex(where: { $0.size == size }) {
                        self.chunkAttempts[index].status = succeeded ? .succeeded : .failed
                    }

                case .responseReceived(let response):
                    self.debugLLMResponse = response
                }
            }

            // Capture reasoning from scanner
            if let llmScanner = scanner as? DarkPatternLLMScanner {
                reasoning = llmScanner.lastReasoning
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
            // Capture reasoning even on error
            if let llmScanner = scanner as? DarkPatternLLMScanner {
                reasoning = llmScanner.lastReasoning
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
            let jsCode = try await modifier.modify(pattern: pattern, html: currentPageHTML)

            // Execute the JavaScript in the WebView
            if let executeJS = executeJavaScript {
                try await executeJS(jsCode)
            }

            modification.status = .applied
            modification.appliedJavaScript = jsCode
            modifications[pattern.id] = modification

            print("[DarkPatternViewModel] Applied modification for: \(pattern.title)")

        } catch {
            modification.status = .failed(error.localizedDescription)
            modifications[pattern.id] = modification
            print("[DarkPatternViewModel] Failed to apply modification: \(error)")
        }
    }

    private func revertModification(for pattern: DarkPattern) async {
        guard var modification = modifications[pattern.id] else { return }

        modification.status = .applying
        modifications[pattern.id] = modification

        do {
            // Step 1: Restore original HTML (no network fetch)
            if let setHTML = setPageHTML {
                try await setHTML(originalPageHTML)
            }

            // Step 2: Mark this pattern as pending (reverted)
            modification.status = .pending
            modification.appliedJavaScript = nil
            modifications[pattern.id] = modification

            // Step 3: Re-apply all OTHER patterns that are still applied
            for (_, mod) in modifications where mod.status == .applied {
                if let jsCode = mod.appliedJavaScript, let executeJS = executeJavaScript {
                    try await executeJS(jsCode)
                }
            }

            print("[DarkPatternViewModel] Reverted: \(pattern.title), re-applied \(appliedCount) other patches")

        } catch {
            modification.status = .applied
            modifications[pattern.id] = modification
            print("[DarkPatternViewModel] Failed to revert: \(error)")
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
