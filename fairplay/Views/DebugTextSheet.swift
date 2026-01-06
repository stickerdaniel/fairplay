import SwiftUI

struct DebugTextSheet: View {
    let title: String
    let content: String
    var showBackendBadge: Bool = false
    var htmlPercentage: Int = 0
    var usedBackend: LLMBackend? = nil
    var usedMLXModel: MLXModel? = nil
    var chunkAttempts: [ChunkAttempt] = []
    @Environment(\.dismiss) private var dismiss

    private var hasBadges: Bool {
        (showBackendBadge && usedBackend != nil) || htmlPercentage > 0 || !chunkAttempts.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if hasBadges {
                        HStack(spacing: 8) {
                            // Backend badges (only if showBackendBadge)
                            if showBackendBadge, let backend = usedBackend {
                                Text(backend.displayName)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.blue.opacity(0.15), in: .capsule)
                                    .foregroundStyle(.blue)

                                if backend == .mlx, let model = usedMLXModel {
                                    Text(model.displayName)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.purple.opacity(0.15), in: .capsule)
                                        .foregroundStyle(.purple)
                                }
                            }

                            // Percentage badge (always show if > 0)
                            if htmlPercentage > 0 {
                                Text("\(htmlPercentage)%")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.orange.opacity(0.15), in: .capsule)
                                    .foregroundStyle(.orange)
                            }

                            // Chunk attempt badges (grey=running, green=succeeded, red=failed)
                            ForEach(chunkAttempts) { attempt in
                                let (bgColor, fgColor): (Color, Color) = switch attempt.status {
                                case .running: (.secondary.opacity(0.15), .secondary)
                                case .succeeded: (.green.opacity(0.15), .green)
                                case .failed: (.red.opacity(0.15), .red)
                                }
                                Text("\(attempt.size / 1000)K")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(bgColor, in: .capsule)
                                    .foregroundStyle(fgColor)
                            }
                        }
                    }

                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = content
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

#Preview {
    DebugTextSheet(
        title: "Test",
        content: "Sample content here\nWith multiple lines\nAnd more text..."
    )
}
