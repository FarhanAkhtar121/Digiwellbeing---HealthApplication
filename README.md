# Digiwellbeing

A modern SwiftUI iOS app that delivers a comprehensive health dashboard with Google and Microsoft sign‑in, HealthKit integration, and a clean, minimal UI. It shows VO2 Max, Sleep Quality, Blood Oxygen (SpO₂), Heart Rate, Steps & Distance, Workouts, Menstrual Cycle, Hypertension Alerts, Sleep Apnea insights, and Noise Monitoring. The app includes a Summary page, and a Sharing page to manage up to three caretakers.

On a real device with permissions granted, HealthKit values populate the dashboard. On the Simulator (where HealthKit is unavailable), the app automatically falls back to high‑quality demo data and shows a small "Demo data" banner.

## Features
- Secure sign‑in with Google and Microsoft (Azure AD)
- Health Dashboard (2×2 top grid + additional cards)
  - VO2 Max, Sleep Quality, Blood Oxygen chart/value
  - Heart Rate card (tap to open live monitor)
  - Steps & Distance with hourly bar chart
  - Workouts preview (tap to see details)
  - Menstrual Cycle, Hypertension Alert, Sleep Apnea, Noise Level
- Summary page with pinned insights (mock data)
- Sharing page to add/manage up to 3 caretakers
- Bottom Tab Bar: Home (Dashboard), Summary, Sharing
- Welcome header with the signed‑in username and Logout on every page
- Simulator fallback for all metrics so the UI never looks empty

## Architecture
- SwiftUI + Combine for UI/state
- HealthKit for health data
- GoogleSignIn and MSAL (Microsoft Authentication Library) for SSO
- Views: `DashboardView`, `SummaryView`, `SharingView`, `HeartMonitorView`
- Managers: `AuthManager`, `HealthKitManager`, `ConnectivityManager`
- App entry: `DigiwellbeingApp` → `ContentView` → `HomeTabsView`
- Charts: lightweight custom line and bar charts for fast rendering

### Key Implementation Notes
- `HealthKitManager`
  - Exposes `vo2Max`, `sleepScore`, `spo2Avg`, `bloodOxygenSamples`, `heartRate`, and `heartRateHistory`
  - `requestAuthorization()` detects HealthKit availability; on Simulator or denial it sets `useMockData = true` and loads demo values
  - Provides live Heart Rate streaming on device; timer‑driven mocks on Simulator
- `DashboardView`
  - Observes `HealthKitManager` and calls `requestAuthorization()` in `.task`
  - Shows a banner when `useMockData` is true
  - Top 2×2 cards are driven by manager values
- `AuthManager`
  - Handles Google sign‑in via GoogleSignIn and placeholder Microsoft via MSAL (replace mock with real flow when ready)
  - Logout clears published auth state and returns to Sign In screen

## Requirements
- Xcode 15 or later
- iOS 16 or later (Swift concurrency in use)
- A real iPhone (for HealthKit data). Simulator is supported with demo data.

## Getting Started
1. Clone the repository and open `Digiwellbeing.xcodeproj` in Xcode.
2. Set your Bundle Identifier (Targets → Digiwellbeing → General).
3. Add Swift Package dependencies (File → Add Packages…):
   - Google Sign‑In: `https://github.com/google/GoogleSignIn-iOS`
   - MSAL (Microsoft): `https://github.com/AzureAD/microsoft-authentication-library-for-objc`
   - Add them to the `Digiwellbeing` app target.
4. Configure Info.plist (Targets → Digiwellbeing → Info):
   - URL Types (CFBundleURLTypes)
     - Google: add your Reversed Client ID as a URL scheme (e.g., `com.googleusercontent.apps.<client-id>`)
     - Microsoft: add `msauth.<your.bundle.id>` as a URL scheme
   - Add String keys:
     - `GIDClientID` = your Google OAuth client ID
     - `MSALClientId` = your Azure App (client) ID
     - `MSALRedirectUri` = `msauth.<your.bundle.id>://auth`
5. Enable HealthKit capability (Signing & Capabilities → + Capability → HealthKit).
6. Add privacy strings in Info.plist (if missing):
   - `NSHealthShareUsageDescription` → "This app reads health data to show your dashboard."
7. Build & Run:
   - Simulator: you’ll see demo data with a banner
   - Device: accept Health access prompts; real values populate where available

## Using the App
- Sign in with Google or Microsoft → you land on the Dashboard
- Bottom tabs:
  - Home: Dashboard cards and charts
  - Summary: condensed insights (mock data)
  - Sharing: add up to 3 caretakers (name + contact), swipe to delete
- Tap the Heart Rate card → opens the heart monitor (live on device, mocked on Simulator)
- Tap Workouts preview → see a simple workouts list
- Logout from the top‑right button on any page

## Troubleshooting
- "Your app is missing support for the following URL schemes…"
  - Add your Google Reversed Client ID under URL Types in Info.plist
- Deprecation: `OpenURLOptionsKey`
  - Handled via SwiftUI `.onOpenURL`; no `UIApplicationDelegate` needed
- Combine ambiguous import
  - Use `import Combine` only; do not apply access modifiers to imports
- HealthKit shows empty values on Simulator
  - By design, app shows demo data with a banner; use a real device for live data

## Project Structure
```
Digiwellbeing/
  ContentView.swift        // Sign-in flow → TabView (Home/Summary/Sharing)
  DashboardView.swift      // Health dashboard (2×2 grid + cards)
  SummaryView.swift        // Mock summary page
  SharingView.swift        // Caretaker management (max 3)
  Managers/
    AuthManager.swift      // Google/MSAL sign-in, logout
    HealthKitManager.swift // HealthKit + simulator fallback
    ConnectivityManager.swift
  Assets.xcassets/
  Info.plist
```

## Roadmap
- Complete MSAL sign‑in flow (replace placeholder)
- Persist caretakers (UserDefaults/Core Data)
- Deeper HealthKit reads (sample ranges, trends, VO₂ queries, stages of sleep)
- Push notifications for alerts (hypertension, noise, apnea)
- watchOS improvements and Live Activities
- Localization and theming

## License
No license specified. Add a license if you plan to share or distribute.
