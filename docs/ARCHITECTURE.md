# SoulTrail — Frontend Architecture

> Premium Flutter mobile app for emotion‑driven travel & wishlist, using clean modular architecture and reusable UI components.

---

## 1. Overview

The SoulTrail frontend is a **feature-based Flutter app** with a strong separation of concerns:
- **App Layer** — bootstrap, theming, routing
- **Core Layer** — shared config, networking, storage, errors, utilities
- **UI Layer** — reusable design system (theme, glassmorphic & neumorphic components, skeleton loaders, media widgets)
- **Feature Modules** — self‑contained (Auth, Places, Wishlist, Admin) with their own API, providers, and presentations
- **Models Layer** — shared typed data structures across features

The project is designed for both **Android** and **iOS**, using:
- **Riverpod** for state management
- **Dio** for networking
- **flutter_secure_storage** for auth tokens
- **go_router** for navigation with guards
- Custom theming with `EmotionTheme` for dynamic gradients

---

## 2. Directory Structure

frontend/
├── android/ # Android runner/config (manifest, gradle)
├── ios/ # iOS runner/config (plist, xcworkspace)
├── lib/ # Flutter source code
│ ├── app/ # App bootstrapping, main widget, routing
│ ├── core/ # Shared config, network, storage, errors, utils
│ ├── ui/ # Global themes, reusable components, skeletons, media widgets
│ ├── features/ # Feature-based modules
│ ├── models/ # Shared typed data models
│ └── main.dart # Entry point calling bootstrap()
├── assets/ # Animations, audio, icons, images
├── pubspec.yaml # Dependencies and asset registry
├── .env # Environment variables
└── docs/ # Project documentation (API.md, ARCHITECTURE.md)

---

## 3. Layers & Responsibilities

### 3.1 App Layer (`lib/app`)
- **app.dart** → Root widget (`MaterialApp.router`), sets `AppTheme`, initializes router.
- **router.dart** → Configures `go_router` routes with guards checking auth state via providers.
- **bootstrap.dart** → Initializes environment vars (`Env.load()`), networking (`DioClient`), secure storage, logging.

### 3.2 Core Layer (`lib/core`)
- **config/**
  - `env.dart` → Loads `.env` variables into constants.
  - `constants.dart` → Holds fixed constants, API paths.
- **network/**
  - `dio_client.dart` → Singleton `Dio` with interceptors (auth, logging, error handling).
  - `api_result.dart` → Wrapper for success/error responses.
- **storage/**
  - `token_storage.dart` → Secure auth token persistence.
- **errors/**
  - `app_exception.dart` → Custom exception types.
  - `error_mapper.dart` → Maps API/server errors to user‑friendly messages.
- **utils/**
  - `formatters.dart` → Display format helpers.
  - `validators.dart` → Input validation functions.

### 3.3 UI Layer (`lib/ui`)
- **theme/**
  - `app_theme.dart` → Base Material theme.
  - `emotion_theme.dart` → Gradient/colors based on emotion.
- **components/**
  - `glass_card.dart` → Blurred glassmorphic container.
  - `neumorphic_button.dart` → Soft shadow clickable button.
  - `emotion_chip.dart`, `gradient_button.dart`, `verified_badge.dart`
  - Skeleton loaders under `components/skeletons/`
  - Media widgets under `components/media/`

### 3.4 Feature Modules (`lib/features`)
Each feature has:
- **data/** → API wrappers (`*_api.dart`), making `Dio` calls and returning typed models wrapped in `ApiResult`.
- **providers/** → Riverpod providers for feature state + calling API methods.
- **presentation/** → Screens and widgets, consuming providers’ state.

Example:
features/wishlist/
├── data/wishlist_api.dart
├── providers/wishlist_providers.dart
└── presentation/wishlist_screen.dart

### 3.5 Models Layer (`lib/models`)
- `place.dart`, `user.dart`, `wishlist_item.dart`
- Pure Dart data classes with `fromJson` and `toJson` methods.
- Used across multiple features to keep types consistent.

---

## 4. Data Flow

**UI (Screen)** → triggers action via **Provider** → calls **API class** → uses **DioClient** to hit backend → gets JSON → parsed into **Model** → Provider updates **state** → UI rebuilds.

Error path:
- API throws/returns error → captured in `ApiResult.error` → transformed by `ErrorMapper` → displayed in UI.

---

## 5. Environment Handling

- `.env` file in project root loaded during `bootstrap()`.
- Variables available via `Env.apiBaseUrl`, etc.
- HTTPS strongly recommended for iOS (ATS compliance).

---

## 6. Navigation Structure

Using **go_router**:
- AuthGuard blocks protected routes if `authProviders.isLoggedIn` is false.
- Public routes: login, register, explore places list.
- Protected routes: wishlist screen, profile, admin panel.

---

## 7. Platform Integration

### Android
- Internet permission in `AndroidManifest.xml`.
- Min SDK 21 for core dependencies.
  
### iOS
- ATS in `Info.plist` — HTTPS only for production.
- CocoaPods manages iOS packages.

---

## 8. Deployment Notes

- Ensure `.env` points to production API.
- All images/audio served from HTTPS for iOS store approval.
- Test API endpoints with Postman against `API.md` spec before building releases.

---

## 9. Principles Followed

- **Clean architecture** — separate concerns, injectable dependencies.
- **DRY** — reusable UI components.
- **Typed models** — no raw `Map` in UI.
- **Centralized configuration** — constants, envs in one place.
- **Error resilience** — user‑friendly messages, consistent handling.

---

## 10. References

- [API.md](./API.md) — Detailed API contracts for backend integration.
- [Flutter docs](https://flutter.dev)
- [Riverpod](https://riverpod.dev)
- [Dio](https://pub.dev/packages/dio)

---
