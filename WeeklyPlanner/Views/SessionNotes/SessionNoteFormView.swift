import SwiftUI

struct SessionNoteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SessionNoteViewModel()

    let appointment: Appointment
    let client: Client?
    let existingNote: SessionNote?

    @State private var content = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var riskLevel: RiskLevel = .low
    @State private var progressRating: Int = 3

    init(appointment: Appointment, client: Client?, existingNote: SessionNote? = nil) {
        self.appointment = appointment
        self.client = client
        self.existingNote = existingNote
    }

    var body: some View {
        NavigationStack {
            Form {
                // Client Info Header
                Section {
                    HStack {
                        if let client = client {
                            Circle()
                                .fill(avatarColor(for: client))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Text(initials(for: client))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }

                            VStack(alignment: .leading) {
                                Text(client.name)
                                    .font(.headline)
                                Text(formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading) {
                                Text("Session Note")
                                    .font(.headline)
                                Text(formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(appointment.sessionType?.rawValue.capitalized ?? "Session")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Session Content
                Section("Session Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }

                // Tags
                Section("Tags") {
                    VStack(alignment: .leading, spacing: 8) {
                        if !tags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.caption)
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                                }
                            }
                        }

                        HStack {
                            TextField("Add tag", text: $newTag)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                if !newTag.isEmpty {
                                    tags.append(newTag)
                                    newTag = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(newTag.isEmpty)
                        }
                    }

                    // Common tags suggestions
                    if tags.isEmpty {
                        HStack(spacing: 6) {
                            Text("Suggestions:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(["Anxiety", "Depression", "Progress", "Breakthrough"], id: \.self) { suggestion in
                                Button(suggestion) {
                                    tags.append(suggestion)
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                // Clinical Assessment
                Section("Clinical Assessment") {
                    Picker("Risk Level", selection: $riskLevel) {
                        ForEach(RiskLevel.allCases, id: \.self) { level in
                            HStack {
                                Circle()
                                    .fill(colorForRiskLevel(level))
                                    .frame(width: 8, height: 8)
                                Text(level.rawValue.capitalized)
                            }
                            .tag(level)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress Rating")
                            Spacer()
                            Text("\(progressRating)/5")
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { rating in
                                Button {
                                    progressRating = rating
                                } label: {
                                    Image(systemName: rating <= progressRating ? "star.fill" : "star")
                                        .foregroundColor(rating <= progressRating ? .yellow : .gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingNote != nil ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveNote() }
                    }
                    .disabled(viewModel.isSaving || content.isEmpty)
                }
            }
            .onAppear {
                loadExistingNote()
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: appointment.scheduledAt)
    }

    private func loadExistingNote() {
        guard let note = existingNote else { return }
        content = note.content ?? ""
        tags = note.tags ?? []
        riskLevel = note.riskLevel ?? .low
        progressRating = note.progressRating ?? 3
    }

    private func saveNote() async {
        guard let clientId = appointment.clientId else { return }

        let input = SessionNoteInput(
            clientId: clientId,
            sessionId: appointment.id,
            content: content,
            sessionDate: appointment.scheduledAt,
            tags: tags.isEmpty ? nil : tags,
            riskLevel: riskLevel,
            progressRating: progressRating
        )

        let success = await viewModel.saveNote(input)

        if success {
            dismiss()
        }
    }

    private func initials(for client: Client) -> String {
        let parts = client.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(client.name.prefix(2)).uppercased()
    }

    private func avatarColor(for client: Client) -> Color {
        let hash = abs(client.name.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        return colors[hash % colors.count]
    }

    private func colorForRiskLevel(_ level: RiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Session Note Summary Card

struct SessionNoteSummaryCard: View {
    let note: SessionNote
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text("Progress Note")
                    .font(.headline)
                Spacer()
                if let riskLevel = note.riskLevel {
                    RiskLevelBadge(level: riskLevel)
                }
            }

            Divider()

            // Content Preview
            if let content = note.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .lineLimit(4)
                    .foregroundColor(.primary)
            }

            // Tags
            if let tags = note.tags, !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags.prefix(5), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            }

            // AI Tags (if different from manual tags)
            if let aiTags = note.aiTags, !aiTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI-Detected Themes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(aiTags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if let rating = note.progressRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                        }
                    }
                }
                Spacer()
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
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

struct RiskLevelBadge: View {
    let level: RiskLevel

    private var color: Color {
        switch level {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        Text(level.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// MARK: - Empty Note View

struct SessionNoteEmptyView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(.blue.opacity(0.6))

            Text("No Progress Note")
                .font(.headline)

            Text("Add a note to document this session")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("Add Note", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
