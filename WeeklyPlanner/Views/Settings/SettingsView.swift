import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var calendarSyncVM: CalendarSyncViewModel
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("defaultView") private var defaultView = "week"
    @State private var showingAPIKeySettings = false
    @State private var showingVoiceSettings = false

    var body: some View {
        NavigationStack {
            List {
                // Google Calendar Section
                Section {
                    GoogleCalendarSyncView()
                } header: {
                    Text("Google Calendar")
                } footer: {
                    Text("Sync your appointments with Google Calendar to keep everything in one place.")
                }

                // Voice & AI Section
                Section {
                    Button {
                        showingAPIKeySettings = true
                    } label: {
                        HStack {
                            Label("AI API Keys", systemImage: "key")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Button {
                        showingVoiceSettings = true
                    } label: {
                        HStack {
                            Label("Voice Settings", systemImage: "waveform")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Voice & AI")
                } footer: {
                    Text("Configure API keys for AI processing and voice assistant features.")
                }

                // Preferences Section
                Section("Preferences") {
                    Toggle("Enable Notifications", isOn: $enableNotifications)

                    Picker("Default View", selection: $defaultView) {
                        Text("Week").tag("week")
                        Text("Day").tag("day")
                        Text("List").tag("list")
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://planner-template-preview.onrender.com")!) {
                        HStack {
                            Text("Web Version")
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Data Section
                Section("Data") {
                    Button {
                        // Trigger full sync
                        Task {
                            await calendarSyncVM.syncCalendars()
                        }
                    } label: {
                        Label("Sync All Data", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(calendarSyncVM.isSyncing)

                    if let lastSync = calendarSyncVM.lastSyncTime {
                        HStack {
                            Text("Last Synced")
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAPIKeySettings) {
                APIKeySettingsView()
            }
            .sheet(isPresented: $showingVoiceSettings) {
                VoiceAssistantSettingsView()
            }
        }
    }
}

// MARK: - API Key Settings View

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let keychain = KeychainService.shared

    @State private var claudeAPIKey = ""
    @State private var openAIAPIKey = ""
    @State private var elevenLabsAPIKey = ""
    @State private var showingClaudeKey = false
    @State private var showingOpenAIKey = false
    @State private var showingElevenLabsKey = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SecureTextField(
                        title: "Claude API Key",
                        text: $claudeAPIKey,
                        isRevealed: $showingClaudeKey
                    )
                } header: {
                    Text("Claude (Anthropic)")
                } footer: {
                    Text("Primary AI provider for processing voice notes and generating responses.")
                }

                Section {
                    SecureTextField(
                        title: "OpenAI API Key",
                        text: $openAIAPIKey,
                        isRevealed: $showingOpenAIKey
                    )
                } header: {
                    Text("OpenAI (Fallback)")
                } footer: {
                    Text("Used as fallback when Claude is unavailable.")
                }

                Section {
                    SecureTextField(
                        title: "ElevenLabs API Key",
                        text: $elevenLabsAPIKey,
                        isRevealed: $showingElevenLabsKey
                    )
                } header: {
                    Text("ElevenLabs")
                } footer: {
                    Text("Used for high-quality text-to-speech in the voice assistant.")
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveKeys()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadKeys()
            }
        }
    }

    private func loadKeys() {
        claudeAPIKey = keychain.claudeAPIKey ?? ""
        openAIAPIKey = keychain.openAIAPIKey ?? ""
        elevenLabsAPIKey = keychain.elevenLabsAPIKey ?? ""
    }

    private func saveKeys() {
        keychain.claudeAPIKey = claudeAPIKey.isEmpty ? nil : claudeAPIKey
        keychain.openAIAPIKey = openAIAPIKey.isEmpty ? nil : openAIAPIKey
        keychain.elevenLabsAPIKey = elevenLabsAPIKey.isEmpty ? nil : elevenLabsAPIKey
    }
}

// MARK: - Secure Text Field

struct SecureTextField: View {
    let title: String
    @Binding var text: String
    @Binding var isRevealed: Bool

    var body: some View {
        HStack {
            if isRevealed {
                TextField(title, text: $text)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                SecureField(title, text: $text)
                    .textContentType(.password)
            }

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(CalendarSyncViewModel())
}
