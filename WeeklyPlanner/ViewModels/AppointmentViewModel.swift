import Foundation
import Combine

@MainActor
class AppointmentViewModel: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedDate = Date()
    @Published var currentWeekStart: Date

    private let _apiClient = APIClient.shared
    private let calendar = Calendar.current

    // Public access for voice assistant
    var apiClient: APIClient { _apiClient }

    init() {
        // Set current week start to Monday
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        currentWeekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
    }

    // MARK: - Week Navigation

    var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: currentWeekStart) }
    }

    var weekRange: (start: String, end: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.string(from: currentWeekStart)
        let end = formatter.string(from: weekDates.last ?? currentWeekStart)
        return (start, end)
    }

    func goToPreviousWeek() {
        if let newStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) {
            currentWeekStart = newStart
            Task { await loadAppointments() }
        }
    }

    func goToNextWeek() {
        if let newStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) {
            currentWeekStart = newStart
            Task { await loadAppointments() }
        }
    }

    func goToToday() {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        currentWeekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        selectedDate = today
        Task { await loadAppointments() }
    }

    // MARK: - Data Operations

    func loadAppointments() async {
        isLoading = true
        error = nil

        do {
            let range = weekRange
            appointments = try await _apiClient.getAppointmentsByDateRange(startDate: range.start, endDate: range.end)
        } catch {
            self.error = error.localizedDescription
            print("Error loading appointments: \(error)")
        }

        isLoading = false
    }

    func loadAllAppointments() async {
        isLoading = true
        error = nil

        do {
            appointments = try await _apiClient.getAllAppointments()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createAppointment(_ input: AppointmentInput) async -> Bool {
        do {
            _ = try await _apiClient.createAppointment(input)
            await loadAppointments()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func updateAppointment(id: String, input: AppointmentInput) async -> Bool {
        do {
            try await _apiClient.updateAppointment(id: id, input: input)
            await loadAppointments()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteAppointment(id: String) async -> Bool {
        do {
            try await _apiClient.deleteAppointment(id: id)
            await loadAppointments()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    func appointmentsForDate(_ date: Date) -> [Appointment] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return appointments.filter { $0.date == dateString }.sorted { $0.startTime < $1.startTime }
    }

    func appointmentsForHour(_ hour: Int, on date: Date) -> [Appointment] {
        appointmentsForDate(date).filter { appointment in
            let appointmentHour = calendar.component(.hour, from: appointment.startTime)
            return appointmentHour == hour
        }
    }

    // Statistics
    var totalHoursThisWeek: Double {
        let totalMinutes = appointments.reduce(0) { $0 + $1.duration }
        return Double(totalMinutes) / 60.0
    }

    var appointmentCountByCategory: [AppointmentCategory: Int] {
        var counts: [AppointmentCategory: Int] = [:]
        for appointment in appointments {
            let category = appointment.category ?? .other
            counts[category, default: 0] += 1
        }
        return counts
    }

    var busiestDay: String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var countsByDate: [String: Int] = [:]
        for appointment in appointments {
            countsByDate[appointment.date, default: 0] += 1
        }

        guard let maxEntry = countsByDate.max(by: { $0.value < $1.value }),
              let date = formatter.date(from: maxEntry.key) else {
            return nil
        }

        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
