import SwiftUI

struct AppointmentCardView: View {
    let appointment: Appointment

    private var categoryColor: Color {
        switch appointment.category {
        case .work:
            return .blue
        case .personal:
            return .green
        case .meeting:
            return .purple
        case .other, .none:
            return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 0) {
                Text(appointment.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(appointment.startTimeFormatted)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(4)
    }
}

#Preview {
    VStack {
        AppointmentCardView(appointment: Appointment(
            id: "1",
            clientId: nil,
            therapistId: "therapist-1",
            scheduledAt: Date(),
            duration: 50,
            sessionType: .individual,
            status: .scheduled,
            googleEventId: nil,
            notes: "Team Meeting",
            client: nil,
            createdAt: Date(),
            updatedAt: nil
        ))

        AppointmentCardView(appointment: Appointment(
            id: "2",
            clientId: "client-1",
            therapistId: "therapist-1",
            scheduledAt: Date(),
            duration: 50,
            sessionType: .individual,
            status: .scheduled,
            googleEventId: nil,
            notes: "Client Session",
            client: nil,
            createdAt: Date(),
            updatedAt: nil
        ))
    }
    .padding()
}
