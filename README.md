# Weekly Planner iOS App

A native iOS app for the Weekly Planner, built with SwiftUI and connecting to the existing Render backend.

## Features

- **Weekly View**: 7-day calendar grid with time slots from 6 AM to 10 PM
- **Daily View**: Detailed day view with timeline, statistics, and daily notes
- **Appointment Management**: Create, edit, and delete appointments
- **Google Calendar Sync**: Sign in with Google and sync all your calendars
- **Categories**: Color-coded appointments (work, personal, meeting, other)
- **Statistics**: Track total hours, appointment counts, and busiest days

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. File > New > Project
3. Choose "App" under iOS
4. Configure:
   - Product Name: `WeeklyPlanner`
   - Team: Your Apple Developer Team
   - Organization Identifier: `com.yourname`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployments: iOS 16.0

5. Save to: `/Users/jonathanprocter/Desktop/WeeklyPlanner-iOS/`

### 2. Copy Source Files

After creating the project, copy all the `.swift` files from the `WeeklyPlanner/` folder into your Xcode project:

```
WeeklyPlanner/
├── WeeklyPlannerApp.swift
├── Models/
│   ├── Appointment.swift
│   ├── User.swift
│   ├── DailyNote.swift
│   └── GoogleCalendar.swift
├── Views/
│   ├── MainTabView.swift
│   ├── WeeklyView/
│   │   ├── WeeklyGridView.swift
│   │   └── AppointmentCardView.swift
│   ├── DailyView/
│   │   └── DailyDetailView.swift
│   ├── Appointments/
│   │   ├── AppointmentListView.swift
│   │   ├── AppointmentDetailView.swift
│   │   └── AppointmentFormView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── GoogleCalendarSyncView.swift
├── ViewModels/
│   ├── AppointmentViewModel.swift
│   └── CalendarSyncViewModel.swift
├── Services/
│   ├── APIClient.swift
│   └── GoogleCalendarService.swift
└── Utilities/
    ├── DateExtensions.swift
    └── ColorExtensions.swift
```

### 3. Configure Google Sign-In (Optional)

To enable Google Calendar sync:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google Calendar API
4. Create OAuth 2.0 credentials (iOS)
5. Download the configuration and update in `GoogleCalendarService.swift`:
   ```swift
   private let clientId = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
   private let redirectURI = "com.yourapp.weeklyplanner:/oauth2callback"
   ```
6. Add URL scheme to Info.plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.yourapp.weeklyplanner</string>
           </array>
       </dict>
   </array>
   ```

### 4. Build and Run

1. Select a simulator or connected device
2. Press Cmd+R to build and run
3. The app will connect to `https://planner-template-preview.onrender.com`

## Architecture

- **SwiftUI**: Declarative UI framework
- **MVVM**: Model-View-ViewModel pattern
- **Async/Await**: Modern Swift concurrency
- **tRPC**: Compatible HTTP client for backend API

## API Endpoints

The app connects to these tRPC endpoints:

| Endpoint | Description |
|----------|-------------|
| `appointments.getByDateRange` | Get appointments for a week |
| `appointments.getAll` | Get all appointments |
| `appointments.create` | Create new appointment |
| `appointments.update` | Update existing appointment |
| `appointments.delete` | Delete appointment |
| `appointments.syncFromGoogle` | Sync Google Calendar events |
| `dailyNotes.getByDate` | Get daily note |
| `dailyNotes.upsert` | Save daily note |

## Screenshots

The app includes:
- Tab bar navigation (Week, Day, Appointments, Settings)
- Weekly calendar grid with colored appointment cards
- Daily timeline with statistics
- Appointment detail and edit sheets
- Google Calendar sync settings

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## License

MIT License
