import SwiftUI

struct DarkPatternRow: View {
    let pattern: DarkPattern
    let modification: PatternModification?
    let onToggle: () async -> Void
    let onRetry: () async -> Void

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

            if isFailed {
                Button {
                    Task { await onRetry() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.orange)
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
        Text(pattern.type.rawValue)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15), in: .capsule)
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch pattern.type {
        case .hiddenDecline:
            return .red
        case .confusingLanguage:
            return .orange
        case .visualManipulation:
            return .purple
        case .forcedAction:
            return .pink
        case .preselectedOptions:
            return .blue
        }
    }
}

#Preview {
    List {
        DarkPatternRow(
            pattern: DarkPattern(
                id: UUID(),
                type: .hiddenDecline,
                title: "Hidden Reject Button",
                description: "The reject button has low contrast",
                elementSelector: ".btn"
            ),
            modification: nil,
            onToggle: {},
            onRetry: {}
        )

        DarkPatternRow(
            pattern: DarkPattern(
                id: UUID(),
                type: .confusingLanguage,
                title: "Confusing Text",
                description: "Double negative language",
                elementSelector: ".text"
            ),
            modification: PatternModification(patternId: UUID(), status: .applied),
            onToggle: {},
            onRetry: {}
        )

        DarkPatternRow(
            pattern: DarkPattern(
                id: UUID(),
                type: .visualManipulation,
                title: "Visual Trick",
                description: "Misleading colors",
                elementSelector: ".colors"
            ),
            modification: PatternModification(patternId: UUID(), status: .failed("Error")),
            onToggle: {},
            onRetry: {}
        )
    }
}
