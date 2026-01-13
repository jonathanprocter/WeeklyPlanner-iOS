import SwiftUI

@main
struct WeeklyPlannerApp: App {
    @StateObject private var appointmentVM = AppointmentViewModel()
    @StateObject private var calendarSyncVM = CalendarSyncViewModel()
    @StateObject private var clientVM = ClientViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appointmentVM)
                .environmentObject(calendarSyncVM)
                .environmentObject(clientVM)
                .task {
                    // Load clients on app launch
                    await clientVM.loadClients()
                }
        }
    }
}
