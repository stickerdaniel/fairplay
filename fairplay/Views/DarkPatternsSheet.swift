import SwiftUI

struct DarkPatternsSheet: View {
    @Bindable var viewModel: DarkPatternViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.patterns) { pattern in
                        DarkPatternRow(
                            pattern: pattern,
                            modification: viewModel.modifications[pattern.id],
                            onToggle: { await viewModel.togglePattern(pattern) },
                            onRetry: { await viewModel.retryModification(for: pattern) }
                        )
                    }
                } header: {
                    headerView
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dark Patterns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.isSheetPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(24)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.patterns.count) patterns detected")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.appliedCount > 0 {
                Text("\(viewModel.appliedCount) fix\(viewModel.appliedCount == 1 ? "" : "es") applied")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .textCase(nil)
    }
}

#Preview {
    @Previewable @State var viewModel = DarkPatternViewModel()

    Color.gray
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DarkPatternsSheet(viewModel: viewModel)
        }
        .task {
            // Simulate finding patterns
            viewModel.patterns = [
                DarkPattern(
                    id: UUID(),
                    type: .hiddenDecline,
                    title: "Hidden Reject Button",
                    description: "The 'Reject All' button has low contrast and smaller text than 'Accept'",
                    elementSelector: ".cookie-banner .reject-btn"
                ),
                DarkPattern(
                    id: UUID(),
                    type: .confusingLanguage,
                    title: "Confusing Opt-Out",
                    description: "Double negative language makes it unclear how to decline",
                    elementSelector: ".preferences-modal .opt-out"
                ),
            ]
            viewModel.scanState = .patternsFound
            for pattern in viewModel.patterns {
                viewModel.modifications[pattern.id] = PatternModification(patternId: pattern.id)
            }
        }
}
