import SwiftUI

struct DailySummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VoiceDictationViewModel()
    @StateObject private var aiService = AIProcessingService()

    @State private var isGeneratingSummary = false
    @State private var aiSummary: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView

                    // Today's reminders
                    remindersSection

                    // AI Summary (if generated)
                    if let summary = aiSummary {
                        aiSummarySection(summary)
                    }

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.headline)

            Text("End of Day Review")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.purple)
                Text("Today's Voice Notes")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.getTodaysReminders().count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(8)
            }

            let reminders = viewModel.getTodaysReminders()

            if reminders.isEmpty {
                Text("No voice notes recorded today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(reminders, id: \.id) { reminder in
                    ReminderSummaryCard(reminder: reminder)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - AI Summary Section

    private func aiSummarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Summary")
                    .font(.headline)
            }

            Text(summary)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isGeneratingSummary {
                ProgressView("Generating summary...")
                    .padding()
            } else if aiSummary == nil {
                Button {
                    generateAISummary()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate AI Summary")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Acknowledge & Close")
                    .font(.headline)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Actions

    private func generateAISummary() {
        isGeneratingSummary = true

        Task {
            do {
                let reminders = viewModel.getTodaysReminders()
                // For now, generate from reminders only (sessions would come from API)
                let summary = try await aiService.generateDailySummary(reminders: reminders, sessions: [])
                aiSummary = summary
            } catch {
                self.error = error.localizedDescription
            }
            isGeneratingSummary = false
        }
    }
}

// MARK: - Reminder Summary Card

struct ReminderSummaryCard: View {
    let reminder: VoiceReminder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)

                // Category
                if let category = reminder.aiSuggestedCategory {
                    Text(category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Time
                Text(reminder.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Transcription
            Text(reminder.transcription)
                .font(.subheadline)
                .lineLimit(3)

            // Client name if available
            if let clientName = reminder.clientName {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text(clientName)
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            // Follow-ups if processed
            if let followUps = reminder.aiExtractedFollowUps, !followUps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Follow-ups:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ForEach(followUps, id: \.self) { followUp in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(followUp)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private var priorityColor: Color {
        switch reminder.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    DailySummarySheet()
}
