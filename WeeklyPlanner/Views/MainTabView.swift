import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appointmentVM: AppointmentViewModel
    @StateObject private var notificationService = NotificationService()
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ExpandableWeeklyView()
                    .tabItem {
                        Label("Week", systemImage: "calendar")
                    }
                    .tag(0)

                DailyDetailView()
                    .tabItem {
                        Label("Day", systemImage: "sun.max")
                    }
                    .tag(1)

                AppointmentListView()
                    .tabItem {
                        Label("Appointments", systemImage: "list.bullet")
                    }
                    .tag(2)

                VoiceAssistantView(apiClient: appointmentVM.apiClient)
                    .tabItem {
                        Label("Assistant", systemImage: "waveform")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(4)
            }

            // Floating dictation button (shown on all tabs except Voice Assistant)
            if selectedTab != 3 {
                FloatingDictationButton(
                    onReminderSaved: { reminder in
                        // Handle saved reminder - could trigger notification or show toast
                        print("Reminder saved: \(reminder.transcription)")
                    }
                )
            }
        }
        .task {
            await appointmentVM.loadAppointments()
            // Setup notifications
            notificationService.registerCategories()
            if await notificationService.requestAuthorization() {
                try? await notificationService.scheduleEndOfDaySummary()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppointmentViewModel())
        .environmentObject(CalendarSyncViewModel())
}
