import Foundation

/// LLM-powered implementation of dark pattern modification (Stage 2)
/// Based on Schäfer et al. (2025) - "Using LLMs to Remove Manipulative Design from Websites"
@MainActor
final class DarkPatternLLMModifier: PatternModifierProtocol {
    private let llmService: LLMService

    /// Last modification logs for debugging
    private(set) var lastLogs: String = ""

    private var systemPrompt: String {
        UserDefaults.standard.string(forKey: "modifierSystemPrompt") ?? ModifierPrompts.defaultSystem
    }

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    func modify(pattern: DarkPattern, html: String, chunkSize: Int? = nil) async throws -> String {
        // Reuse the chunk size that succeeded during scanning, or fall back to largest modifier size
        let htmlLimit = chunkSize ?? LLMService.backend.modifierChunkSizes.first ?? 3000

        let prompt = """
        Fix this dark pattern:

        Type: \(pattern.category.name)
        Title: \(pattern.title)
        Description: \(pattern.description)
        CSS Selector: \(pattern.elementSelector)

        SPECIFIC FIX INSTRUCTIONS FOR \(pattern.category.name.uppercased()):
        \(pattern.category.fixInstructions)

        HTML context:
        ```html
        \(String(html.prefix(htmlLimit)))
        ```

        Generate JavaScript following the instructions above.
        """

        // Build logs
        var logs = """
        === MODIFY REQUEST ===
        Category: \(pattern.category.name)
        Title: \(pattern.title)
        Selector: \(pattern.elementSelector)

        Fix Instructions:
        \(pattern.category.fixInstructions)

        """

        print("[Modifier] \(logs)")

        let response = try await llmService.analyze(content: prompt, systemPrompt: systemPrompt)

        logs += """

        === LLM RESPONSE ===
        \(response)

        """

        // Clean up the response - remove markdown code blocks if present
        var jsCode = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if jsCode.hasPrefix("```javascript") {
            jsCode = String(jsCode.dropFirst(13))
        } else if jsCode.hasPrefix("```js") {
            jsCode = String(jsCode.dropFirst(5))
        } else if jsCode.hasPrefix("```") {
            jsCode = String(jsCode.dropFirst(3))
        }
        if jsCode.hasSuffix("```") {
            jsCode = String(jsCode.dropLast(3))
        }

        let finalCode = jsCode.trimmingCharacters(in: .whitespacesAndNewlines)

        logs += """
        === FINAL JS CODE ===
        \(finalCode)
        """

        lastLogs = logs
        print("[Modifier] Final JS:\n\(finalCode)")

        return finalCode
    }

    func revert(pattern: DarkPattern, originalHTML: String) async throws -> String {
        // For revert, we would need to reload the page or undo the JavaScript changes
        // For now, return original HTML (actual implementation would refresh the WebView)
        return originalHTML
    }
}
