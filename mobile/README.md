# Delegads CRM Mobile App

Dashboard app for agency management — iOS and Android.

## Setup

### Install Flutter
```bash
# macOS
brew install flutter

# Linux
sudo snap install flutter --classic
# OR download from https://docs.flutter.dev/get-started/install/linux

# Verify
flutter doctor
```

### Run
```bash
cd mobile
flutter pub get
flutter run
```

### Build APK (Android)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Build iOS
```bash
cd ios && pod install && cd ..
flutter build ios --release
# Open build/ios/Runner.xcworkspace in Xcode to archive
```

## Configuration

API URL is set in `lib/config/api_config.dart`.

You can override it in the Settings screen within the app (saved to secure storage).

Default: `http://localhost:8086` (CRM API)

For physical devices, set the API URL to your machine's LAN IP (e.g. `http://192.168.1.50:8086`).

## Features

- **Login**: Sanctum token authentication (email + password)
- **Dashboard**: KPI stat cards, conversion funnel, recent leads
- **Leads**: List, search by name/phone, filter by stage, tap for detail view
- **Campaigns**: Active campaigns with status badges
- **Designs**: Pending design approvals with type/status info
- **Settings**: Configurable API URL, logout
- **Material 3** design with deep purple theme
- Works on **iOS** and **Android**

## Architecture

- **Provider** for state management (lightweight, no extra deps)
- **flutter_secure_storage** for secure token persistence
- **http** package for REST API calls
- Models with `fromJson` factories for type-safe JSON parsing
- Reusable widgets (`StatCard`, `StageBadge`, `FunnelChart`)

## API Endpoints (CRM)

All endpoints under `/api/v1` require `Authorization: Bearer <token>` header.

| Method | Path                          | Purpose                    |
|--------|-------------------------------|----------------------------|
| POST   | `/api/login`                  | Get Sanctum token          |
| GET    | `/api/v1/metrics`             | Aggregated dashboard data  |
| GET    | `/api/v1/leads`               | List leads (paginated)     |
| GET    | `/api/v1/leads/{id}`          | Lead detail + conversations|
| GET    | `/api/v1/campaigns`           | List campaigns             |
| GET    | `/api/v1/design-jobs`         | List design jobs           |

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   └── api_config.dart          # API base URL, endpoints
│   ├── models/
│   │   ├── lead.dart                # Lead model
│   │   ├── campaign.dart            # Campaign model
│   │   ├── design_job.dart          # DesignJob model
│   │   └── metrics.dart             # Metrics/dashboard data
│   ├── services/
│   │   └── api_service.dart         # HTTP client with Sanctum auth
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── leads_screen.dart
│   │   ├── lead_detail_screen.dart
│   │   ├── campaigns_screen.dart
│   │   ├── designs_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/
│       ├── stat_card.dart
│       ├── stage_badge.dart
│       └── funnel_chart.dart
├── pubspec.yaml
└── README.md
```

## Stage Colors

| Stage              | Color  |
|--------------------|--------|
| new                | gray   |
| initial            | blue   |
| interested         | cyan   |
| pricing_discussion | amber  |
| ready_to_buy       | orange |
| payment_pending    | yellow |
| onboarding         | teal   |
| active             | green  |
| cold               | slate  |

## Status Legend

- **Hot lead** = red
- **Warm lead** = orange
- **Cold lead** = blue
