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

    private var systemPrompt: String {
        UserDefaults.standard.string(forKey: "scannerSystemPrompt") ?? ScannerPrompts.defaultSystem
    }

    private var userPromptTemplate: String {
        UserDefaults.standard.string(forKey: "scannerUserPrompt") ?? ScannerPrompts.defaultUser
    }

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
                // Don't overwrite lastRawResponse - keep the actual LLM response for debugging
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

        // Sanitize JSON: escape unescaped newlines inside string values
        jsonString = sanitizeJSON(jsonString)

        guard let data = jsonString.data(using: .utf8) else {
            throw ScanError.jsonParsingFailed("Failed to convert response to data")
        }

        do {
            let decoded = try JSONDecoder().decode(LLMReasoningResponse.self, from: data)
            print("[DarkPatternLLMScanner] Reasoning: \(decoded.reasoning.prefix(200))...")
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

    /// Sanitize JSON string to handle common LLM output issues
    /// - Escapes literal newlines inside string values
    /// - Handles control characters
    nonisolated private func sanitizeJSON(_ json: String) -> String {
        var result = ""
        var insideString = false
        var previousChar: Character = " "

        for char in json {
            if char == "\"" && previousChar != "\\" {
                insideString.toggle()
                result.append(char)
            } else if insideString {
                // Inside a JSON string value - escape problematic characters
                switch char {
                case "\n":
                    result.append("\\n")
                case "\r":
                    result.append("\\r")
                case "\t":
                    result.append("\\t")
                default:
                    result.append(char)
                }
            } else {
                result.append(char)
            }
            previousChar = char
        }

        return result
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
