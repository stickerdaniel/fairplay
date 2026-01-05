import Foundation

enum ScanError: LocalizedError {
    case allAttemptsFailed
    case jsonParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .allAttemptsFailed:
            return "All scan attempts failed"
        case .jsonParsingFailed(let details):
            return "Failed to parse LLM response: \(details)"
        }
    }
}

/// LLM-powered implementation of dark pattern detection (Stage 1)
/// Identifies manipulative patterns without modifying - modification happens in Stage 2
@MainActor
final class DarkPatternLLMScanner: DarkPatternScannerProtocol {
    private let llmService: LLMService

    // Debug: store last request/response for inspection
    private(set) var lastHTMLSent: String = ""
    private(set) var lastRawResponse: String = ""

    private let systemPrompt = """
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

    private let userPromptTemplate = """
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

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    func scan(html: String) async throws -> [DarkPattern] {
        // Try progressively smaller HTML chunks to fit context window
        // Chunk sizes are backend-specific (llama has larger context than Foundation Models)
        let chunkSizes = LLMService.backend.scannerChunkSizes
        var lastError: Error?
        lastRawResponse = ""

        for chunkSize in chunkSizes {
            let truncatedHTML = String(html.prefix(chunkSize))
            lastHTMLSent = truncatedHTML

            let prompt = userPromptTemplate.replacingOccurrences(of: "%HTML%", with: truncatedHTML)

            do {
                let response = try await llmService.analyze(content: prompt, systemPrompt: systemPrompt)
                lastRawResponse = response
                return try parsePatterns(from: response)
            } catch {
                lastError = error
                lastRawResponse = "ERROR: \(error)"
                print("[DarkPatternLLMScanner] Attempt with \(chunkSize) chars failed: \(error)")
            }
        }

        throw lastError ?? ScanError.allAttemptsFailed
    }

    nonisolated private func parsePatterns(from response: String) throws -> [DarkPattern] {
        // Extract JSON from response (handle potential markdown code blocks)
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code block if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            throw ScanError.jsonParsingFailed("Failed to convert response to data")
        }

        do {
            let decoded = try JSONDecoder().decode(LLMReasoningResponse.self, from: data)
            print("[DarkPatternLLMScanner] Reasoning: \(decoded.reasoning)")
            return decoded.patterns.map { response in
                DarkPattern(
                    id: UUID(),
                    type: mapPatternType(response.type),
                    title: response.title,
                    description: response.description,
                    elementSelector: response.selector
                )
            }
        } catch {
            print("[DarkPatternLLMScanner] JSON parsing failed: \(error)")
            print("[DarkPatternLLMScanner] Raw response: \(jsonString.prefix(500))...")
            throw ScanError.jsonParsingFailed(error.localizedDescription)
        }
    }

    nonisolated private func mapPatternType(_ typeString: String) -> DarkPattern.PatternType {
        let lowercased = typeString.lowercased()

        // Map paper's pattern categories to our types
        if lowercased.contains("false hierarchy") || lowercased.contains("hierarchy") {
            return .visualManipulation
        } else if lowercased.contains("hidden") {
            return .hiddenDecline
        } else if lowercased.contains("confirmshaming") || lowercased.contains("shame") {
            return .confusingLanguage
        } else if lowercased.contains("forced") || lowercased.contains("countdown") ||
                  lowercased.contains("timer") || lowercased.contains("urgency") {
            return .forcedAction
        } else if lowercased.contains("trick") || lowercased.contains("question") {
            return .confusingLanguage
        } else if lowercased.contains("preselect") {
            return .preselectedOptions
        }

        return .visualManipulation // Default fallback
    }
}

// MARK: - JSON Response Models

private struct LLMReasoningResponse: Decodable {
    let reasoning: String
    let patterns: [LLMPatternResponse]
}

private struct LLMPatternResponse: Decodable {
    let type: String
    let title: String
    let description: String
    let selector: String
    let evidence: String?
}
