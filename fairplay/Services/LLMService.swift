import Foundation
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientFoundationModels
import FoundationModels

// MARK: - Backend Configuration

enum LLMBackend: String, CaseIterable {
    case foundationModels = "Foundation Models"
    case llama = "Qwen (llama.cpp)"

    var displayName: String { rawValue }

    /// Maximum context tokens for this backend
    var maxContextTokens: Int {
        switch self {
        case .foundationModels: return 4096
        case .llama: return 8192
        }
    }

    /// Scanner HTML chunk sizes (largest to smallest for fallback)
    var scannerChunkSizes: [Int] {
        switch self {
        case .foundationModels: return [8000, 4000, 2000]
        case .llama: return [16000, 8000, 4000]
        }
    }

    /// Modifier HTML prefix limit
    var modifierHTMLLimit: Int {
        switch self {
        case .foundationModels: return 3000
        case .llama: return 8000
        }
    }

    /// Whether this backend requires a model download
    var requiresDownload: Bool {
        switch self {
        case .foundationModels: return false
        case .llama: return true
        }
    }
}

// MARK: - LLM Service

@Observable
@MainActor
final class LLMService {
    // MARK: - Configuration

    /// Toggle between mock data and real LLM
    static var useMockData = false

    /// Selected backend (default: llama for better quality/context)
    static var backend: LLMBackend = .llama

    // MARK: - State

    private(set) var isLoading = false
    private(set) var isReady = false
    private(set) var downloadProgress: Double = 0
    private(set) var errorMessage: String?

    private var session: LLMSession?

    // MARK: - Initialization

    /// Call this at app launch to pre-load the model in background
    func loadModelInBackground() {
        guard !Self.useMockData else {
            isReady = true
            return
        }

        Task {
            await loadModel()
        }
    }

    /// Load the model based on selected backend
    func loadModel() async {
        guard !Self.useMockData else {
            isReady = true
            return
        }

        isLoading = true
        errorMessage = nil
        downloadProgress = 0

        do {
            switch Self.backend {
            case .foundationModels:
                try await loadFoundationModels()
            case .llama:
                try await loadLlamaModel()
            }
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
            print("[LLMService] Failed to load model: \(error)")
        }

        isLoading = false
    }

    // MARK: - Foundation Models Backend

    private func loadFoundationModels() async throws {
        print("[LLMService] Loading Apple Foundation Models...")
        session = LLMSession(model: .foundationModels())
        print("[LLMService] Foundation Models ready")
    }

    // MARK: - llama.cpp Backend

    private func loadLlamaModel() async throws {
        print("[LLMService] Downloading Qwen2.5-Coder-3B...")

        let model = LLMSession.DownloadModel.llama(
            id: "Qwen/Qwen2.5-Coder-3B-Instruct-GGUF",
            model: "qwen2.5-coder-3b-instruct-q4_k_m.gguf",
            parameter: .init(
                context: 8192,
                temperature: 0.3,
                topP: 0.9
            )
        )

        try await model.downloadModel { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress
                print("[LLMService] Download progress: \(Int(progress * 100))%")
            }
        }

        session = LLMSession(model: model)
        print("[LLMService] Qwen2.5-Coder ready")
    }

    // MARK: - Analysis API

    /// Analyze content with a system prompt, returns full response
    func analyze(content: String, systemPrompt: String) async throws -> String {
        guard let session else {
            throw LLMServiceError.modelNotLoaded
        }

        session.messages = [.system(systemPrompt)]
        return try await session.respond(to: content)
    }

    /// Stream analysis for real-time token output
    func streamAnalysis(
        content: String,
        systemPrompt: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let session else {
            throw LLMServiceError.modelNotLoaded
        }

        session.messages = [.system(systemPrompt)]
        return try await session.streamResponse(to: content)
    }
}

// MARK: - Errors

enum LLMServiceError: LocalizedError {
    case modelNotLoaded
    case analysisFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "LLM model not loaded. Please wait for initialization."
        case .analysisFailed:
            return "Failed to analyze content."
        }
    }
}
