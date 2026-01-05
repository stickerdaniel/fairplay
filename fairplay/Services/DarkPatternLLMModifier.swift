import Foundation

/// LLM-powered implementation of dark pattern modification (Stage 2)
/// Based on Schäfer et al. (2025) - "Using LLMs to Remove Manipulative Design from Websites"
@MainActor
final class DarkPatternLLMModifier: PatternModifierProtocol {
    private let llmService: LLMService

    private var systemPrompt: String {
        UserDefaults.standard.string(forKey: "modifierSystemPrompt") ?? ModifierPrompts.defaultSystem
    }

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    func modify(pattern: DarkPattern, html: String) async throws -> String {
        // HTML limit is backend-specific (llama has larger context than Foundation Models)
        let htmlLimit = LLMService.backend.modifierHTMLLimit

        let prompt = """
        Fix this dark pattern:

        Type: \(pattern.type.rawValue)
        Title: \(pattern.title)
        Description: \(pattern.description)
        CSS Selector: \(pattern.elementSelector)

        HTML context:
        ```html
        \(String(html.prefix(htmlLimit)))
        ```

        Generate JavaScript to fix this pattern. Remember: don't remove elements, just make them fair.
        """

        let response = try await llmService.analyze(content: prompt, systemPrompt: systemPrompt)

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

        return jsCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func revert(pattern: DarkPattern, originalHTML: String) async throws -> String {
        // For revert, we would need to reload the page or undo the JavaScript changes
        // For now, return original HTML (actual implementation would refresh the WebView)
        return originalHTML
    }
}
