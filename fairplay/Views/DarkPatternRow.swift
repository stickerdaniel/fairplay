import SwiftUI

struct DarkPatternRow: View {
    let pattern: DarkPattern
    let modification: PatternModification?
    let onToggle: () async -> Void

    @State private var showLogs = false

    private var isApplied: Bool {
        modification?.status == .applied
    }

    private var isApplying: Bool {
        modification?.status == .applying
    }

    private var isFailed: Bool {
        if case .failed = modification?.status {
            return true
        }
        return false
    }

    private var hasLogs: Bool {
        modification?.modifierLogs != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(pattern.title)
                    .font(.headline)

                Text(pattern.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                patternTypeBadge
            }

            Spacer()

            // Show logs button for failed or applied items with logs
            if (isFailed || isApplied) && hasLogs {
                Button {
                    showLogs = true
                } label: {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(isFailed ? .orange : .secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isApplying else { return }
            Task { await onToggle() }
        }
        .opacity(isApplying ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: modification?.status)
        .sheet(isPresented: $showLogs) {
            LogsSheet(
                title: pattern.title,
                category: pattern.category.name,
                logs: modification?.modifierLogs ?? "No logs available"
            )
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch modification?.status {
        case .none, .pending:
            Image(systemName: "circle")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)

        case .applying:
            ProgressView()
                .scaleEffect(0.9)

        case .applied:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)

        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.red)
        }
    }

    private var patternTypeBadge: some View {
        Text(pattern.category.name)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15), in: .capsule)
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch pattern.category.id {
        case "false_hierarchy":
            return .purple
        case "hidden_information":
            return .red
        case "confirmshaming":
            return .orange
        case "forced_action":
            return .pink
        case "trick_questions":
            return .yellow
        case "preselected_options":
            return .blue
        default:
            return .gray
        }
    }
}

// MARK: - Logs Sheet

struct LogsSheet: View {
    let title: String
    let category: String
    let logs: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Modifier Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.headline)
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    List {
        if let category = CategoryLoader.category(forId: "hidden_information") {
            DarkPatternRow(
                pattern: DarkPattern(
                    id: UUID(),
                    category: category,
                    title: "Hidden Reject Button",
                    description: "The reject button has low contrast",
                    elementSelector: ".btn"
                ),
                modification: nil,
                onToggle: {}
            )
        }

        if let category = CategoryLoader.category(forId: "confirmshaming") {
            DarkPatternRow(
                pattern: DarkPattern(
                    id: UUID(),
                    category: category,
                    title: "Guilt Trip Text",
                    description: "No, I don't want to save money",
                    elementSelector: ".text"
                ),
                modification: PatternModification(patternId: UUID(), status: .applied),
                onToggle: {}
            )
        }

        if let category = CategoryLoader.category(forId: "false_hierarchy") {
            var mod = PatternModification(patternId: UUID(), status: .failed("JS execution error"))
            let _ = { mod.modifierLogs = "Sample logs here..." }()
            DarkPatternRow(
                pattern: DarkPattern(
                    id: UUID(),
                    category: category,
                    title: "Visual Hierarchy",
                    description: "Unequal button styling",
                    elementSelector: ".buttons"
                ),
                modification: mod,
                onToggle: {}
            )
        }
    }
}
