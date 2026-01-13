import SwiftUI

struct SessionPrepCardView: View {
    let prep: SessionPrep
    let clientName: String
    let onRefresh: () -> Void

    private var content: SessionPrepContent {
        prep.prep
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Session Prep")
                    .font(.headline)
                Spacer()
                Text("AI Generated")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(6)
            }

            Divider()

            // Session Focus
            if let focus = content.sessionFocus, !focus.isEmpty {
                PrepSection(
                    title: "Session Focus",
                    icon: "target",
                    iconColor: .purple
                ) {
                    Text(focus)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }

            // Last Session Summary / Tonal Analysis
            if let summary = content.lastSessionSummary, !summary.isEmpty {
                PrepSection(
                    title: "Last Session",
                    icon: "clock.arrow.circlepath",
                    iconColor: .blue
                ) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }

            // Key Themes
            if let themes = content.keyThemes, !themes.isEmpty {
                PrepSection(
                    title: "Key Themes",
                    icon: "tag",
                    iconColor: .orange
                ) {
                    FlowLayout(spacing: 8) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(12)
                        }
                    }
                }
            }

            // Treatment Goals
            if let goals = content.treatmentGoals, !goals.isEmpty {
                PrepSection(
                    title: "Treatment Goals",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(goals.prefix(4), id: \.self) { goal in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(goal)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }

            // Suggested Topics / Interventions
            if let topics = content.suggestedTopics, !topics.isEmpty {
                PrepSection(
                    title: "Suggested Topics",
                    icon: "list.bullet.clipboard",
                    iconColor: .blue
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(topics.prefix(5), id: \.self) { topic in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                                    .padding(.top, 6)
                                Text(topic)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }

            // Significant Quotes
            if let quotes = content.significantQuotes, !quotes.isEmpty {
                PrepSection(
                    title: "Significant Quotes",
                    icon: "quote.bubble",
                    iconColor: .indigo
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(quotes.prefix(3), id: \.self) { quote in
                            Text("\"\(quote)\"")
                                .font(.subheadline)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Risk Alerts
            if let risks = content.riskAlerts, !risks.isEmpty {
                PrepSection(
                    title: "Risk Factors",
                    icon: "exclamationmark.triangle",
                    iconColor: .red
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(risks, id: \.self) { risk in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(risk)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
            }

            // Client Strengths / Keywords
            if let strengths = content.clientStrengths, !strengths.isEmpty {
                PrepSection(
                    title: "Client Strengths",
                    icon: "star",
                    iconColor: .yellow
                ) {
                    FlowLayout(spacing: 8) {
                        ForEach(strengths.prefix(6), id: \.self) { strength in
                            Text(strength)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                }
            }

            // Follow-up Items
            if let followUp = content.followUpItems, !followUp.isEmpty {
                PrepSection(
                    title: "Follow-Up Items",
                    icon: "arrow.right.circle",
                    iconColor: .cyan
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(followUp.prefix(4), id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                Text(item)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("Generated \(prep.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let sessionNum = content.sessionNumber {
                    Text("• Session #\(sessionNum)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct PrepSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            content
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Loading View

struct SessionPrepLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.purple)
                .opacity(isAnimating ? 1.0 : 0.5)
                .scaleEffect(isAnimating ? 1.0 : 0.95)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text("Generating Session Prep...")
                .font(.headline)

            Text("Analyzing recent sessions to prepare insights")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            ProgressView()
                .progressViewStyle(.circular)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Empty State View

struct SessionPrepEmptyView: View {
    let clientName: String
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundColor(.purple.opacity(0.6))

            Text("AI Session Prep")
                .font(.headline)

            Text("Generate an AI-powered preparation brief for your session with \(clientName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onGenerate) {
                Label("Generate Prep", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Error View

struct SessionPrepErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)

            Text("Unable to generate prep")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
