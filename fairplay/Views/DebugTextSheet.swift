import SwiftUI

struct DebugTextSheet: View {
    let title: String
    let content: String
    var showBackendBadge: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if showBackendBadge {
                        Text(LLMService.backend.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.blue.opacity(0.15), in: .capsule)
                            .foregroundStyle(.blue)
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
