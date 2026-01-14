import SwiftUI

struct FloatingDictationButton: View {
    @StateObject private var viewModel = VoiceDictationViewModel()
    @State private var showingOverlay = false
    @State private var isExpanded = false

    var client: Client?
    var session: Appointment?
    var onReminderSaved: ((VoiceReminder) -> Void)?

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if isExpanded {
                    expandedView
                } else {
                    collapsedButton
                }
            }
            Spacer()
        }
        .padding(.trailing, 16)
        .sheet(isPresented: $showingOverlay) {
            QuickDictationOverlay(
                viewModel: viewModel,
                client: client,
                session: session,
                onSaved: { reminder in
                    onReminderSaved?(reminder)
                    showingOverlay = false
                },
                onDismiss: {
                    showingOverlay = false
                }
            )
        }
        .onAppear {
            viewModel.setContext(client: client, session: session)
        }
    }

    // MARK: - Collapsed Button

    private var collapsedButton: some View {
        Button {
            showingOverlay = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.purple)
                        .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .accessibilityLabel("Start voice note")
    }

    // MARK: - Expanded View (Recording)

    private var expandedView: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button {
                viewModel.cancelDictation()
                isExpanded = false
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Transcription preview
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.partialTranscription.isEmpty ? "Listening..." : viewModel.partialTranscription)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(viewModel.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Audio level indicator
            AudioLevelView(level: viewModel.audioLevel)
                .frame(width: 40)

            // Stop button
            Button {
                Task {
                    _ = await viewModel.stopDictation()
                    isExpanded = false
                    showingOverlay = true
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.red))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Audio Level View

struct AudioLevelView: View {
    let level: Float
    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
            }
        }
        .frame(height: 24)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount)
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 24

        if level > threshold {
            let progress = min(1, (level - threshold) * Float(barCount))
            return baseHeight + (maxHeight - baseHeight) * CGFloat(progress)
        }
        return baseHeight
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        if level > threshold {
            return index >= barCount - 1 ? .red : .purple
        }
        return Color.gray.opacity(0.3)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        FloatingDictationButton()
    }
}
