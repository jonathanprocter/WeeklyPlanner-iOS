import SwiftUI

struct QuickDictationOverlay: View {
    @ObservedObject var viewModel: VoiceDictationViewModel
    @Environment(\.dismiss) private var dismiss

    var client: Client?
    var session: Appointment?
    var onSaved: ((VoiceReminder) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var showingAIProcessing = false
    @State private var selectedPriority: ReminderPriority = .medium
    @State private var selectedCategory: ReminderCategory = .sessionFollowUp

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with context
                if let client = client {
                    clientContextHeader(client)
                }

                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Recording section
                        if viewModel.isRecording {
                            recordingView
                        } else if viewModel.currentReminder != nil {
                            reviewView
                        } else {
                            startView
                        }
                    }
                    .padding()
                }

                // Bottom actions
                if !viewModel.isRecording {
                    bottomActions
                }
            }
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.reset()
                        onDismiss?()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "An error occurred")
            }
        }
    }

    // MARK: - Client Context Header

    private func clientContextHeader(_ client: Client) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(client.name.prefix(1))
                        .font(.headline)
                        .foregroundColor(.purple)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Note for")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(client.name)
                    .font(.headline)
            }

            Spacer()

            if let session = session {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(session.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)

            Text("Tap to Start Recording")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Speak your note and it will be transcribed automatically")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.startDictation()
                }
            } label: {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Start Recording")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated recording indicator
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(1 + CGFloat(viewModel.audioLevel) * 0.3)
                    .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)

                Circle()
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 80, height: 80)

                Image(systemName: "mic.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }

            // Duration
            Text(viewModel.formattedDuration)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(.primary)

            // Real-time transcription
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(viewModel.partialTranscription.isEmpty ? "Listening..." : viewModel.partialTranscription)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()

            // Stop button
            Button {
                Task {
                    _ = await viewModel.stopDictation()
                }
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Recording")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Review View

    private var reviewView: some View {
        VStack(spacing: 20) {
            // Transcription
            VStack(alignment: .leading, spacing: 8) {
                Label("Transcription", systemImage: "text.quote")
                    .font(.headline)

                Text(viewModel.currentReminder?.transcription ?? "")
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            // Priority selector
            VStack(alignment: .leading, spacing: 8) {
                Label("Priority", systemImage: "flag.fill")
                    .font(.headline)

                Picker("Priority", selection: $selectedPriority) {
                    ForEach(ReminderPriority.allCases, id: \.self) { priority in
                        Text(priority.rawValue.capitalized).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Category selector
            VStack(alignment: .leading, spacing: 8) {
                Label("Category", systemImage: "folder.fill")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ReminderCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }

            // AI Processing toggle
            if viewModel.hasTranscription {
                Toggle(isOn: $showingAIProcessing) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("AI Processing")
                                .font(.headline)
                            Text("Extract follow-ups and categorize automatically")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.purple)
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 12) {
            if viewModel.currentReminder != nil {
                if viewModel.isProcessing {
                    ProgressView("Processing with AI...")
                        .padding()
                } else {
                    // Save buttons
                    HStack(spacing: 12) {
                        Button {
                            saveWithoutProcessing()
                        } label: {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                        }

                        if showingAIProcessing {
                            Button {
                                saveWithProcessing()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Save & Process")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Re-record button
                    Button {
                        viewModel.reset()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Re-record")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func saveWithoutProcessing() {
        do {
            var reminder = try viewModel.saveWithoutProcessing()
            reminder.priority = selectedPriority
            reminder.aiSuggestedCategory = selectedCategory
            onSaved?(reminder)
            dismiss()
        } catch {
            viewModel.error = error.localizedDescription
        }
    }

    private func saveWithProcessing() {
        Task {
            do {
                var reminder = try await viewModel.processAndSave()
                reminder.priority = selectedPriority
                onSaved?(reminder)
                dismiss()
            } catch {
                viewModel.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: ReminderCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.purple : Color(.secondarySystemBackground))
                )
        }
    }
}

// MARK: - Preview

#Preview {
    QuickDictationOverlay(viewModel: VoiceDictationViewModel())
}
