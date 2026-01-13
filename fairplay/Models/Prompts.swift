import Foundation

// MARK: - Scanner Prompts

enum ScannerPrompts {
    static var defaultSystem: String {
        let categoryList = CategoryLoader.shared
            .enumerated()
            .map { "\($0.offset + 1). \($0.element.name): \($0.element.scanDescription)" }
            .joined(separator: "\n")

        return """
        You are an expert at identifying dark patterns in web interfaces. Only flag clear manipulation.

        Categories (mutually exclusive):
        \(categoryList)

        Rules:
        - DO NOT invent elements not in the HTML
        - When in doubt, return empty patterns array
        """
    }

    static var defaultUser: String {
        let typeList = CategoryLoader.shared.map { "\"\($0.name)\"" }.joined(separator: ", ")

        return """
        Analyze this HTML for dark patterns. Return JSON with reasoning and patterns array.

        Format: {"reasoning": "...", "patterns": [{"type": "...", "title": "...", "description": "...", "selector": "...", "evidence": "..."}]}

        Types: \(typeList)

        Rules:
        - Only report patterns with evidence from the HTML
        - If none found: {"reasoning": "...", "patterns": []}
        - Return ONLY valid JSON

        HTML:
        ```html
        %HTML%
        ```
        """
    }
}

// MARK: - Modifier Prompts

enum ModifierPrompts {
    static let defaultSystem = """
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

    Return ONLY executable JavaScript code. No explanations, no markdown code blocks.
    Use document.querySelector/querySelectorAll with the provided selector.
    """
}
