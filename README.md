# SCADA Alarm Client

A modern, high-performance Flutter application designed for industrial operators to monitor SCADA (Supervisory Control and Data Acquisition) alarms in real-time. This client connects to a Firebase backend to synchronize active and historical alarms with seamless offline support.

## Features

- **Real-Time Monitoring:** Live updates of active critical, warning, and informational alarms.
- **High-Performance UI:** Built with CustomScrollViews and Slivers for buttery-smooth 60/120fps scrolling.
- **Offline Resilience:** Complete offline caching and synchronization when connectivity is restored.
- **Advanced Filtering:** Instantly filter alerts by severity, acknowledgment status, and date ranges.
- **Deep Diagnostics:** Detailed metrics including trigger values, thresholds, condition states, and equipment sources.
- **Dark Industrial Theme:** A high-contrast, modern UI optimized for readability in varied industrial environments.
- **Haptic & Audio Feedback:** Integrated feedback for critical alerts and interactions.

## Architecture

The project follows a clean, feature-first architecture using Riverpod for state management:

- `lib/core/`: Application-wide services, themes, widgets, and utilities.
- `lib/data/`: Data models (Freezed), Firestore integration, and repositories.
- `lib/features/`: Isolated feature modules (`alerts`, `dashboard`, `history`, `settings`).

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.8.1+)
- Android Studio / Xcode (for mobile deployment)
- Firebase Project configured for Flutter

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd scada_alarm_client
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Code Generation** (If modifying Freezed models)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Firebase Configuration**
   Ensure your `firebase_options.dart` and `google-services.json` are properly configured for your specific Firebase instance.

5. **Run the application**
   ```bash
   flutter run
   ```

## Design System

The application utilizes a dark "Glassmorphism" aesthetic with specific semantic colors:
- **Critical:** `#EF5350` (Red)
- **Warning:** `#FFA726` (Orange)
- **Info:** `#42A5F5` (Blue)
- **Normal/Resolved:** `#66BB6A` (Green)
- **Surfaces:** Deep grays and true blacks (`#0F0F0F`, `#1A1A1A`)

## License

Copyright © 2024. All Rights Reserved.
