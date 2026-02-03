import SwiftUI

/// Editor for managing reading patterns (Serendipity feature)
struct ReadingPatternEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var newPatternType = "topic"
    @State private var newPatternValue = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(DesignTokens.Colors.accent)
                    Text("Reading Patterns")
                        .font(DesignTokens.Typography.headingLarge)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.accent)
                .keyboardShortcut(.escape)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)

            Divider()
                .background(DesignTokens.Colors.surfaceSubtle)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // Explanation
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("How Serendipity Works")
                            .font(DesignTokens.Typography.headingSmall)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("""
                            Serendipity surfaces articles based on your reading patterns. \
                            Patterns are auto-detected from articles you read, but you can also add or remove them manually.
                            """)
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .background(DesignTokens.Colors.surfaceSubtle)

                    // Add new pattern
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Add Pattern")
                            .font(DesignTokens.Typography.headingSmall)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        HStack {
                            Picker("Type", selection: $newPatternType) {
                                Text("Topic").tag("topic")
                                Text("Keyword").tag("keyword")
                                Text("Exclude").tag("excluded")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 250)

                            TextField("Value", text: $newPatternValue)
                                .textFieldStyle(.plain)
                                .padding(DesignTokens.Spacing.sm)
                                .background(DesignTokens.Colors.backgroundTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))

                            Button {
                                addPattern()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(newPatternValue.isEmpty
                                        ? DesignTokens.Colors.textMuted
                                        : DesignTokens.Colors.accent)
                            }
                            .buttonStyle(.plain)
                            .disabled(newPatternValue.isEmpty)
                        }

                        Text(patternTypeDescription)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    Divider()
                        .background(DesignTokens.Colors.surfaceSubtle)

                    // Current patterns
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Text("Current Patterns")
                                .font(DesignTokens.Typography.headingSmall)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)

                            Spacer()

                            Button("Reset All") {
                                Task {
                                    await appState.resetReadingPatterns()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DesignTokens.Colors.error)
                        }

                        if appState.readingPatterns.isEmpty {
                            Text("No patterns yet. Start reading articles to auto-detect patterns, or add them manually.")
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                                .padding(.vertical, DesignTokens.Spacing.md)
                        } else {
                            PatternList(patterns: appState.readingPatterns)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
                .padding(.vertical, DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Colors.backgroundPrimary)
        }
        .frame(width: 550, height: 500)
        .background(DesignTokens.Colors.backgroundSecondary)
        .task {
            await appState.loadReadingPatterns()
        }
    }

    private var patternTypeDescription: String {
        switch newPatternType {
        case "topic":
            return "Topics are weighted keywords extracted from article titles and content"
        case "keyword":
            return "Keywords must appear in the article title or summary"
        case "excluded":
            return "Articles containing excluded terms will be filtered out"
        default:
            return ""
        }
    }

    private func addPattern() {
        guard !newPatternValue.isEmpty else { return }

        Task {
            await appState.addReadingPattern(type: newPatternType, value: newPatternValue)
            newPatternValue = ""
        }
    }
}

struct PatternList: View {
    @Environment(AppState.self) private var appState
    let patterns: [ReadingPattern]

    var body: some View {
        LazyVStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(groupedPatterns.keys.sorted(), id: \.self) { type in
                if let patternsOfType = groupedPatterns[type] {
                    PatternSection(type: type, patterns: patternsOfType)
                }
            }
        }
    }

    private var groupedPatterns: [String: [ReadingPattern]] {
        Dictionary(grouping: patterns, by: { $0.patternType })
    }
}

struct PatternSection: View {
    @Environment(AppState.self) private var appState
    let type: String
    let patterns: [ReadingPattern]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(typeTitle)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            FlowLayout(spacing: DesignTokens.Spacing.sm) {
                ForEach(patterns, id: \.id) { pattern in
                    PatternChip(pattern: pattern) {
                        Task {
                            await appState.deleteReadingPattern(pattern.id)
                        }
                    }
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var typeTitle: String {
        switch type {
        case "topic":
            return "Topics"
        case "keyword":
            return "Keywords"
        case "excluded":
            return "Excluded"
        default:
            return type.capitalized
        }
    }
}

struct PatternChip: View {
    let pattern: ReadingPattern
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(pattern.value)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            if pattern.source == "auto" {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered
                        ? DesignTokens.Colors.textSecondary
                        : DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.fast) {
                    isHovered = hovering
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(chipColor.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(chipColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var chipColor: Color {
        switch pattern.patternType {
        case "topic":
            return DesignTokens.Colors.chipTopic
        case "keyword":
            return DesignTokens.Colors.chipKeyword
        case "excluded":
            return DesignTokens.Colors.chipExcluded
        default:
            return DesignTokens.Colors.textTertiary
        }
    }
}

/// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            var rowWidth: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                    rowWidth = 0
                }

                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                rowWidth = x
                maxHeight = max(maxHeight, size.height)
            }

            self.size = CGSize(width: max(rowWidth - spacing, 0), height: y + maxHeight)
        }
    }
}

#Preview {
    ReadingPatternEditor()
        .environment(AppState())
}
