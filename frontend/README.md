# Naveeka Frontend [Flutter]

> Naveeka is a multi-domain travel app built with Flutter 3.x featuring discovery, maps, activities, hotels, restaurants, trails, transport (buses, trains, flights), messaging, trip planning, and cabs, designed for Android and iOS with a modular, provider-driven architecture. [web:5222]  
> The app consumes a REST backend and uses flutter_dotenv for environment configuration, with Android emulator loopback via 10.0.2.2 for local development. [web:5191][web:5183]

---

## 📂 Project Structure

frontend/ [web:5222]  
├── android/  # Android Gradle project, manifests, signing [web:5222]  
├── ios/      # iOS Xcode workspace, plist, signing [web:5222]  
├── lib/      # Flutter source code [web:5222]  
│ ├── app/                   # Bootstrap, themes, routing (go_router) [web:5224]  
│ ├── core/                  # Config, networking (dio), storage, errors, utils [web:5224]  
│ ├── ui/                    # Design system, reusable widgets, animations [web:5224]  
│ ├── features/              # Feature modules: auth, activities, hotels, restaurants, trails, buses, trains, flights, messages, planning, cabs [web:5224]  
│ └── models/                # Typed data models (Hive/JSON) [web:5224]  
├── assets/   # Images, icons, animations, seed data [web:5222]  
├── pubspec.yaml  # Dependencies, assets, fonts [web:5222]  
└── .env      # Environment variables (loaded with flutter_dotenv) [web:5191]

---

## 🛠 Tech Stack

- Flutter 3.x (Dart ≥ 3.0.0) with Material 3 theming and performance best practices. [web:5222]  
- Riverpod 2.x for state management and providers-based architecture. [web:5232]  
- Dio + interceptors and pretty_dio_logger for resilient networking. [web:5224]  
- flutter_dotenv to inject environment variables (note: visible on web bundles). [web:5191]  
- flutter_secure_storage + shared_preferences + Hive for secure/local storage. [web:5224]  
- cached_network_image, shimmer, lottie, flutter_animate for visuals and UX. [web:5224]  
- go_router for declarative navigation and route guards. [web:5224]  
- google_maps_flutter, geolocator, geocoding, url_launcher for maps & location UX. [web:5224]

---

## ⚙️ Setup & Installation

1) Prerequisites: Install Flutter SDK, Android Studio or VS Code, and Xcode for iOS builds on macOS. [web:5222]  
2) Clone the repo and open the frontend directory in the IDE of choice. [web:5224]  
3) Install dependencies: run `flutter pub get` from the frontend directory. [web:5224]  
4) Create a `.env` file (see .env.example) and ensure API_BASE_URL points to the backend: use `http://10.0.2.2:3000` on Android emulator and `http://localhost:3000` on iOS simulator. [web:5191][web:5183]  
5) For Google Maps, set GOOGLE_MAPS_API_KEY in `.env` and configure platform keys if targeting release. [web:5222]

---

## 🔧 Environment (.env)

Key variables loaded via flutter_dotenv at app bootstrap (ensure `.env` is registered in pubspec assets): [web:5191][web:5222]  
- API_BASE_URL=http://10.0.2.2:3000 (Android emulator loopback) [web:5183]  
- API_BASE_URL_IOS=http://localhost:3000 (iOS simulator) [web:5183]  
- APP_NAME=Naveeka (used in MaterialApp.title and elsewhere) [web:5222]  
- GOOGLE_MAPS_API_KEY=YOUR_KEY (required for google_maps_flutter usage) [web:5222]  
- ASSETS_BASE_URL=https://cdn.naveeka.app (for CDN-served assets if used) [web:5222]  
- TOKEN_STORAGE_KEY, REFRESH_TOKEN_STORAGE_KEY (secure storage keys) [web:5224]  
- ENV=development|staging|production (switches for endpoints/flags if needed) [web:5222]

---

## 🎨 Assets & Fonts

Assets folders are pre-registered in pubspec (images/icons/animations/seed-data and `.env`), and Inter/Poppins fonts are included for UI consistency. [web:5222]  
Add or remove folders under `flutter.assets` in pubspec.yaml and run `flutter pub get` to apply changes. [web:5222]  
Remember that bundling `.env` exposes values in web builds; use server-driven config or obfuscation for web production. [web:5191]

---

## 📱 Running

- Android: Start an Android Emulator and run `flutter run`; API calls hit host via 10.0.2.2 when using local backend. [web:5183]  
- iOS: Start an iOS Simulator and run `flutter run`; API calls hit `http://localhost:3000` when backend runs locally. [web:5183]  
- Web/Desktop (optional): Ensure the API base URL is reachable from the platform networking context. [web:5222]

---

## 🚀 Building for Release

- Android: Configure `android/key.properties` and signing configs, then build AAB with `flutter build appbundle`. [web:5222]  
- iOS: Open `ios/Runner.xcworkspace` in Xcode, set Bundle ID and signing/team, then Archive and upload via Organizer. [web:5222]  
- Make sure release API endpoints and keys (Maps, etc.) are configured appropriately for production. [web:5222]

---

## 🔌 Feature Overview (Frontend)

- Discovery & Search: Unified search screens and curated rails powered by REST endpoints. [web:5224]  
- Maps: Geo overlays from backend in FeatureCollection format rendered with google_maps_flutter. [web:5224]  
- Activities, Hotels, Restaurants, Trails: Browsing, details, photos, availability, quotes, and booking stubs. [web:5224]  
- Transport: Buses/Trains/Flights screens with routes, schedules, fares, and map overlays. [web:5224]  
- Messaging: Threads, messages, reactions, and optional SSE polling/stream handling in the UI. [web:5224]  
- Planning: Trip groups, itinerary pins on maps, expenses, checklist, docs, and ICS export integration UI. [web:5224]  
- Cabs: Ride types, estimates, minimal live status stub, and booking UX. [web:5224]

---

## 🧩 Architecture & Conventions

- Riverpod providers encapsulate state and side effects; UI widgets remain declarative and lean. [web:5232]  
- Networking via Dio with interceptors for auth headers, logging, and error mapping to typed results. [web:5224]  
- Config-driven setup with flutter_dotenv loaded before runApp; use multiple .env files per environment if needed. [web:5191]  
- Keep dependencies and assets organized and update pubspec.yaml accordingly for consistent builds. [web:5222]

---

## ✅ Quality & Lints

- The project uses flutter_lints and a tuned analysis_options.yaml with strict inference and recommended rules. [web:5220]  
- Follow sort_pub_dependencies and general pubspec structure to keep analyzer clean. [web:5241]  
- Run `flutter analyze` and optionally `dart fix --apply` to resolve common issues quickly. [web:5215]

---

## 📄 License

This project is proprietary and developed for the Naveeka application; all rights reserved. [web:5222]
