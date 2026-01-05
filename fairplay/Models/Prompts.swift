import Foundation

// MARK: - Scanner Prompts

enum ScannerPrompts {
    static let defaultSystem = """
    You are an expert at identifying dark patterns (deceptive design) in web interfaces.

    Dark patterns are INTENTIONALLY manipulative UI techniques that trick users. Only flag clear, obvious manipulation - NOT missing features or standard UI conventions.

    Categories to detect:
    1. **False Hierarchy**: REQUIRES two buttons (accept AND decline) where accept is prominent and decline is small/faded. If only one button exists, this is NOT a dark pattern.
    2. **Hidden Information**: REQUIRES both an accept button AND a decline option that exists but is deliberately hard to see (tiny, low-contrast, faded). If no decline option exists at all, this is NOT a dark pattern.
    3. **Confirmshaming**: Guilt-tripping language for declining (e.g., "No, I don't want to save money")
    4. **Forced Action**: Fake countdown timers, false scarcity ("only 3 left!"), artificial urgency
    5. **Trick Questions**: Double negatives or confusing wording that obscures the actual choice
    6. **Preselected Options**: Checkboxes pre-checked for marketing, tracking, or data sharing

    CRITICAL RULES:
    - Only report CERTAIN manipulation, never "possible" or "might be" - if you're not 100% sure, don't report it
    - You MUST quote the exact HTML element in your evidence - if you cannot find it in the input HTML, the pattern does NOT exist
    - DO NOT invent or hallucinate elements like .btn-accept, .cookie-modal, etc. that are not in the actual HTML
    - A page with only text, headings, and navigation links has ZERO dark patterns
    - When in doubt, return an empty patterns array
    """

    static let defaultUser = """
    Analyze this HTML for dark patterns. Return a JSON object with reasoning and patterns.

    Example - clean page with no dark patterns:
    Input: <html><head><title>My Blog</title></head><body><h1>Welcome</h1><p>Thanks for visiting.</p><a href="/about">About</a><a href="/contact">Contact</a></body></html>
    Output: {"reasoning": "Analyzing this HTML for dark patterns. Looking at the first element, we have a <title>My Blog</title> which is just a page title - this is standard and shows no signs of manipulation. The next visually relevant element is <h1>Welcome</h1>, a simple heading that doesn't match any dark pattern category. Then we have <p>Thanks for visiting.</p>, plain informational text with no guilt-tripping or deceptive language. Next, <a href='/about'>About</a> is a standard navigation link - not a hidden decline button, not confirmshaming. Finally, <a href='/contact'>Contact</a> is another standard link. I see no accept/decline button pairs, no pre-checked checkboxes, no countdown timers, no scarcity messages, no double negatives. This is a clean informational page with no dark patterns.", "patterns": []}

    Example - page with dark patterns:
    Output: {"reasoning": "Found dark patterns. Evidence: <button class='btn-accept'>Accept All</button> is large and green while <button class='btn-decline'>decline</button> is tiny gray text. This is False Hierarchy.", "patterns": [{"type": "False Hierarchy", "title": "Unequal Button Styling", "description": "Accept button is prominent while decline is minimized", "selector": ".btn-decline", "evidence": "<button class='btn-decline'>decline</button>"}]}

    Pattern fields:
    - type: One of "False Hierarchy", "Hidden Information", "Confirmshaming", "Forced Action", "Trick Question", "Preselected Options"
    - title: Short descriptive title (max 5 words)
    - description: Brief explanation of why this is manipulative
    - selector: CSS selector to target the element
    - evidence: Copy the exact HTML element(s) that prove this pattern exists

    Rules:
    - Analyze EVERY DOM element in your reasoning before concluding - do not stop until all elements are checked
    - First, write your reasoning with quotes from the actual HTML
    - Only report patterns you can prove with evidence from the HTML
    - If no patterns found, return: {"reasoning": "...", "patterns": []}
    - Return ONLY valid JSON

    HTML to analyze:
    ```html
    %HTML%
    ```
    """
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
}
