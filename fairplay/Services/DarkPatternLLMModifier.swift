import Foundation

/// LLM-powered implementation of dark pattern modification (Stage 2)
/// Based on Schäfer et al. (2025) - "Using LLMs to Remove Manipulative Design from Websites"
@MainActor
final class DarkPatternLLMModifier: PatternModifierProtocol {
    private let llmService: LLMService

    // System prompt based on paper's approach
    private let systemPrompt = """
    You are an AI assistant that helps to design websites by making them less manipulative and more fair for users.

    Your task is to generate JavaScript that fixes the identified dark pattern. The JavaScript will be injected into the page.

    CRITICAL GUARDRAILS (from Schäfer et al. research):
    1. Never remove any actions like buttons or links
    2. Never make buttons look inactive or grayed out if they can be clicked
    3. If two buttons are on the same hierarchical level, make both the same design
    4. Never add any new information to the page
    5. Never add new functionalities
    6. Never change facts or numbers
    7. Never invert the meaning of a statement

    FIXING STRATEGIES:
    - False Hierarchy: Equalize button styling (same size, color, padding, font-weight)
    - Hidden Information: Increase visibility (opacity, contrast, size)
    - Confirmshaming: Replace guilt-trip text with neutral alternatives (e.g., "No thanks" instead of "No, I hate saving money")
    - Forced Action: Hide or remove countdown timers and urgency messages
    - Trick Questions: Simplify confusing wording if possible via textContent changes
    - Preselected Options: Uncheck pre-selected checkboxes

    Return ONLY executable JavaScript code. No explanations, no markdown code blocks.
    Use document.querySelector/querySelectorAll with the provided selector.
    """

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
