import SwiftUI

struct SettingsSheet: View {
    let llmService: LLMService

    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedBackend") private var selectedBackend = LLMBackend.foundationModels.rawValue
    @AppStorage("selectedMLXModel") private var selectedMLXModel = MLXModel.qwen3_4B.rawValue
    @AppStorage("scannerSystemPrompt") private var scannerSystemPrompt = ScannerPrompts.defaultSystem
    @AppStorage("scannerUserPrompt") private var scannerUserPrompt = ScannerPrompts.defaultUser
    @AppStorage("modifierSystemPrompt") private var modifierSystemPrompt = ModifierPrompts.defaultSystem

    var body: some View {
        NavigationStack {
            Form {
                // Backend Selection
                Section("LLM Backend") {
                    Picker("Backend", selection: $selectedBackend) {
                        ForEach(LLMBackend.allCases, id: \.rawValue) { backend in
                            Text(backend.displayName).tag(backend.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    // MLX Model picker (only visible when MLX backend is selected)
                    if selectedBackend == LLMBackend.mlx.rawValue {
                        Picker("Model", selection: $selectedMLXModel) {
                            ForEach(MLXModel.allCases, id: \.rawValue) { model in
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(model.rawValue)
                            }
                        }
                    }
                }

                // Scanner System Prompt
                Section {
                    TextEditor(text: $scannerSystemPrompt)
                        .frame(minHeight: 150)
                        .font(.system(.caption, design: .monospaced))

                    Button("Reset to Default") {
                        scannerSystemPrompt = ScannerPrompts.defaultSystem
                    }
                    .font(.caption)
                } header: {
                    Text("Scanner System Prompt")
                }

                // Scanner User Prompt
                Section {
                    TextEditor(text: $scannerUserPrompt)
                        .frame(minHeight: 150)
                        .font(.system(.caption, design: .monospaced))

                    Button("Reset to Default") {
                        scannerUserPrompt = ScannerPrompts.defaultUser
                    }
                    .font(.caption)
                } header: {
                    Text("Scanner User Prompt")
                } footer: {
                    Text("Use %HTML% as placeholder for the page content")
                }

                // Modifier System Prompt
                Section {
                    TextEditor(text: $modifierSystemPrompt)
                        .frame(minHeight: 150)
                        .font(.system(.caption, design: .monospaced))

                    Button("Reset to Default") {
                        modifierSystemPrompt = ModifierPrompts.defaultSystem
                    }
                    .font(.caption)
                } header: {
                    Text("Modifier System Prompt")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedBackend) { _, _ in
            Task {
                await llmService.loadModel()
            }
        }
        .onChange(of: selectedMLXModel) { _, _ in
            // Only reload if MLX backend is currently selected
            if selectedBackend == LLMBackend.mlx.rawValue {
                Task {
                    await llmService.loadModel()
                }
            }
        }
    }
}

#Preview {
    SettingsSheet(llmService: LLMService())
}
