import SwiftUI

struct GoogleCalendarSyncView: View {
    @EnvironmentObject var viewModel: CalendarSyncViewModel
    @EnvironmentObject var appointmentVM: AppointmentViewModel

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isSignedIn {
                signedInView
            } else {
                signedOutView
            }
        }
    }

    // MARK: - Signed Out View

    private var signedOutView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Not Connected")
                .font(.headline)

            Text("Sign in to sync with Google Calendar")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await viewModel.signIn() }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical)
    }

    // MARK: - Signed In View

    private var signedInView: some View {
        VStack(spacing: 16) {
            // Status Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Connected to Google")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Sign Out") {
                    viewModel.signOut()
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            // Calendar Selection
            if !viewModel.calendars.isEmpty {
                calendarSelector
            }

            // Sync Progress
            if viewModel.isSyncing {
                syncProgressView
            }

            // Sync Button
            Button {
                Task {
                    await viewModel.syncCalendars()
                    await appointmentVM.loadAppointments()
                }
            } label: {
                HStack {
                    if viewModel.isSyncing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(viewModel.isSyncing ? "Syncing..." : "Sync Calendars (2015-2030)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSyncing || viewModel.selectedCalendarIds.isEmpty)

            // Last Sync Time
            if let lastSync = viewModel.lastSyncTime {
                Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Error Display
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Calendar Selector

    private var calendarSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Calendars")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(viewModel.selectedCalendarIds.count == viewModel.calendars.count ? "Deselect All" : "Select All") {
                    if viewModel.selectedCalendarIds.count == viewModel.calendars.count {
                        viewModel.selectedCalendarIds.removeAll()
                    } else {
                        viewModel.selectedCalendarIds = Set(viewModel.calendars.map { $0.id })
                    }
                }
                .font(.caption)
            }

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(viewModel.calendars) { calendar in
                        CalendarToggleRow(
                            calendar: calendar,
                            isSelected: viewModel.selectedCalendarIds.contains(calendar.id)
                        ) {
                            viewModel.toggleCalendar(calendar.id)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Sync Progress

    private var syncProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Syncing: \(viewModel.syncProgress.calendar)")
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text("\(viewModel.syncProgress.current)/\(viewModel.syncProgress.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(viewModel.syncProgress.current), total: Double(max(viewModel.syncProgress.total, 1)))
                .tint(.blue)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Calendar Toggle Row

struct CalendarToggleRow: View {
    let calendar: GoogleCalendar
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Text(calendar.summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
    }
}

#Preview {
    List {
        Section {
            GoogleCalendarSyncView()
        }
    }
    .environmentObject(CalendarSyncViewModel())
    .environmentObject(AppointmentViewModel())
}
