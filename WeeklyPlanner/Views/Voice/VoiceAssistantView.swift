import SwiftUI

struct VoiceAssistantView: View {
    @StateObject private var viewModel: VoiceAssistantService
    @State private var textInput = ""
    @State private var showingSettings = false
    @FocusState private var isTextFieldFocused: Bool

    init(apiClient: APIClient? = nil) {
        _viewModel = StateObject(wrappedValue: VoiceAssistantService(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Conversation history
                conversationView

                Divider()

                // Input area
                inputArea
            }
            .navigationTitle("Voice Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.clearConversation()
                        } label: {
                            Label("Clear Conversation", systemImage: "trash")
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                VoiceAssistantSettingsView()
            }
            .onAppear {
                Task {
                    _ = await viewModel.requestAuthorization()
                }
            }
        }
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Welcome message if empty
                    if viewModel.conversation.messages.isEmpty {
                        welcomeView
                    }

                    // Messages
                    ForEach(viewModel.conversation.messages) { message in
                        MessageBubble(message: message, isSpeaking: viewModel.isSpeaking)
                            .id(message.id)
                    }

                    // Processing indicator
                    if viewModel.isProcessing {
                        HStack {
                            ProgressView()
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.conversation.messages.count) { _ in
                if let lastMessage = viewModel.conversation.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Voice Assistant")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Ask me about your schedule, clients, or session prep")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Quick action buttons
            VStack(spacing: 12) {
                QuickActionButton(
                    title: "What's my next appointment?",
                    icon: "calendar"
                ) {
                    Task {
                        await viewModel.askAboutNextAppointment()
                    }
                }

                QuickActionButton(
                    title: "What's on my schedule today?",
                    icon: "list.bullet.rectangle"
                ) {
                    Task {
                        await viewModel.askAboutTodaySchedule()
                    }
                }
            }
            .padding(.top)

            Spacer()
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 12) {
            // Text input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $textInput)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendTextMessage()
                    }

                // Voice button
                VoiceInputButton(
                    isListening: viewModel.isListening,
                    onTap: {
                        Task {
                            if viewModel.isListening {
                                await viewModel.stopListeningAndProcess()
                            } else {
                                await viewModel.startListening()
                            }
                        }
                    }
                )
            }

            // Status indicators
            if viewModel.isListening {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.isSpeaking {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.purple)
                    Text("Speaking...")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Stop") {
                        viewModel.stopSpeaking()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func sendTextMessage() {
        guard !textInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let message = textInput
        textInput = ""

        Task {
            await viewModel.processTextQuery(message)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage
    let isSpeaking: Bool

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.purple : Color(.secondarySystemBackground))
                    )

                if let intent = message.intent {
                    Text(intent.action.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Voice Input Button

struct VoiceInputButton: View {
    let isListening: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isListening ? Color.red : Color.purple)
                    .frame(width: 44, height: 44)

                if isListening {
                    // Animated pulse
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(1.3)
                        .opacity(0.5)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: isListening
                        )
                }

                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .font(.body)
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel(isListening ? "Stop listening" : "Start voice input")
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - Voice Assistant Settings View

struct VoiceAssistantSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var elevenLabsService = ElevenLabsService()
    @State private var selectedVoiceId: String = ""
    @State private var isLoadingVoices = false
    @AppStorage("voiceAssistantBargeInEnabled") private var bargeInEnabled = false
    @AppStorage("voiceAssistantConversationModeEnabled") private var conversationModeEnabled = false

    var body: some View {
        NavigationStack {
            List {
                Section("Voice Selection") {
                    if isLoadingVoices {
                        HStack {
                            ProgressView()
                            Text("Loading voices...")
                        }
                    } else if elevenLabsService.availableVoices.isEmpty {
                        Button("Load Available Voices") {
                            loadVoices()
                        }
                    } else {
                        ForEach(elevenLabsService.availableVoices) { voice in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(voice.name)
                                        .font(.body)
                                    if let category = voice.category {
                                        Text(category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if voice.voiceId == selectedVoiceId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVoiceId = voice.voiceId
                                elevenLabsService.setVoice(id: voice.voiceId)
                            }
                        }
                    }
                }

                Section("Voice Settings") {
                    Toggle("Use ElevenLabs TTS", isOn: .constant(elevenLabsService.isConfigured))
                        .disabled(true)

                    if !elevenLabsService.isConfigured {
                        Text("Configure your ElevenLabs API key in Settings to enable high-quality voice responses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Conversation") {
                    Toggle("Barge-In (Interruptible)", isOn: $bargeInEnabled)
                    Toggle("Continuous Conversation Mode", isOn: $conversationModeEnabled)
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedVoiceId = elevenLabsService.selectedVoiceId
            }
        }
    }

    private func loadVoices() {
        isLoadingVoices = true
        Task {
            do {
                _ = try await elevenLabsService.getAvailableVoices()
            } catch {
                // Handle error
            }
            isLoadingVoices = false
        }
    }
}

// MARK: - Intent Display Name Extension

extension IntentAction {
    var displayName: String {
        switch self {
        case .queryNextAppointment: return "Schedule Query"
        case .queryClientHistory: return "Client History"
        case .queryPreviousSession: return "Session Lookup"
        case .querySessionPrep: return "Session Prep"
        case .createReminder: return "Create Reminder"
        case .searchClients: return "Client Search"
        case .getSchedule: return "Schedule"
        case .getDailySummary: return "Daily Summary"
        case .getClientInfo: return "Client Info"
        case .unknown: return "General Query"
        }
    }
}

// MARK: - Preview

#Preview {
    VoiceAssistantView()
}
