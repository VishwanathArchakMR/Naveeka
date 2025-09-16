# Naveeka — Full Project README

Naveeka is a full‑stack travel platform with a Flutter 3.x mobile app and a Node/Express backend, covering discovery, maps, activities, hotels, restaurants, trails, transport (buses, trains, flights), messaging, trip planning, and cabs.

---

## Overview

The frontend is a cross‑platform Flutter app (Android + iOS) using Riverpod for state, Dio for networking, and flutter_dotenv for environment configuration, while the backend exposes REST endpoints secured with standard Express middleware.  
Local development uses the Android emulator’s 10.0.2.2 hostname to reach a backend on the host machine (localhost); the iOS simulator typically reaches http://localhost directly.

---

## Repository Structure

C:\app\Naveeka\
├── backend/                         # Node/Express API (MongoDB, REST)  
│   ├── server.js                    # App bootstrap, routes, security, health  
│   ├── services/                    # Domain services (map, messages, planning, hotels, restaurants, trails, trains, etc.)  
│   ├── routes/                      # Express routers grouped by domain  
│   ├── models/                      # Mongoose schemas and indexes  
│   ├── config/                      # Database bootstrap and env  
│   ├── scripts/                     # Seeders and migration utilities  
│   ├── package.json                 # Scripts for dev/prod and seeding  
│   └── .env.example                 # Backend env template (do not commit real .env)  
├── frontend/                        # Flutter mobile app  
│   ├── android/                     # Android runner (Gradle, manifests)  
│   ├── ios/                         # iOS runner (Xcode workspace, plist)  
│   ├── lib/                         # App source: app/core/ui/features/models  
│   │   ├── app/                     # Bootstrap, theming, routing (go_router)  
│   │   ├── core/                    # Config, networking (dio), storage, error mapping, utils  
│   │   ├── ui/                      # Design system, reusable widgets, animations  
│   │   ├── features/                # auth, activities, hotels, restaurants, trails, buses, trains, flights, messages, planning, cabs  
│   │   └── models/                  # Typed data models (Hive/JSON)  
│   ├── assets/                      # Images, icons, animations, seed data  
│   ├── pubspec.yaml                 # Dependencies, assets, fonts  
│   ├── .env.example                 # Frontend env template  
│   └── README.md                    # Frontend guide  
├── docs/                            # API and architecture notes (optional)  
├── .gitignore                       # Monorepo ignore (Flutter + Node)  
└── LICENSE                          # Project licence

---

## Tech Stack

- Flutter 3.x (Dart ≥ 3.0.0) with Material 3 and google_maps_flutter on mobile  
- Riverpod 2.x, Dio + pretty_dio_logger for stateful networking flows  
- flutter_dotenv for runtime configuration via .env files  
- Node.js + Express with MongoDB/Mongoose for API and geospatial features

---

## Getting Started

1) Prerequisites  
- Flutter SDK installed  
- Android Studio/SDK for Android builds  
- Xcode + CocoaPods (macOS) for iOS builds  
- Node.js 18+ and npm for backend

2) Clone and install  
- Backend:
  - cd backend
  - npm install
- Frontend:
  - cd frontend
  - flutter pub get

3) Environment  
- Backend:
  - Copy backend/.env.example to backend/.env and fill values
- Frontend:
  - Copy frontend/.env.example to frontend/.env and fill values
  - Ensure `.env` is listed under assets in frontend/pubspec.yaml for flutter_dotenv

4) Emulator networking  
- Android emulator → use http://10.0.2.2:3000 to reach backend running on host  
- iOS simulator → use http://localhost:3000

---

## Run the Backend (development)

- cd backend  
- npm run dev  
- Health check: GET http://localhost:3000/health returns JSON with DB state and uptime

---

## Run the Mobile App

- Android:
  - Start an Android Emulator
  - Set API_BASE_URL=http://10.0.2.2:3000 in frontend/.env
  - cd frontend && flutter run

- iOS:
  - Start an iOS Simulator
  - Set API_BASE_URL_IOS=http://localhost:3000 in frontend/.env
  - cd frontend/ios && pod install (first time), then cd .. && flutter run

---

## Environment Variables

Frontend (.env):
- API_BASE_URL=http://10.0.2.2:3000
- API_BASE_URL_IOS=http://localhost:3000
- SSE_STREAM_URL=http://10.0.2.2:3000/api/stream
- APP_NAME=Naveeka
- GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
- ASSETS_BASE_URL=https://cdn.naveeka.app
- DEFAULT_COUNTRY=India
- DEFAULT_STATE=Karnataka
- TOKEN_STORAGE_KEY=naveeka_token
- REFRESH_TOKEN_STORAGE_KEY=naveeka_refresh
- ENV=development|staging|production

Backend (.env):
- PORT=3000  
- NODE_ENV=development  
- MONGODB_URI=your_connection_string  
- JWT_SECRET=change_me  
- JWT_EXPIRES_IN=7d  
- CORS_ORIGINS=http://localhost:3000  
- FRONTEND_URL=http://localhost:3000  
- RATE_LIMIT_WINDOW_MS=900000  
- RATE_LIMIT_MAX=200  
- ENABLE_UPLOADS=true  
- CLOUDINARY_CLOUD_NAME=  
- CLOUDINARY_API_KEY=  
- CLOUDINARY_API_SECRET=  
- MEDIA_BASE_FOLDER=naveeka  
- MEDIA_APPEND_ENV=false  
- AI_PROVIDER=mock  
- OPENAI_API_KEY= (if AI_PROVIDER=openai)  
- MAPS_PROVIDER=none|google|mapbox|osm  
- GOOGLE_MAPS_API_KEY= (if using Google Maps server calls)  
- MAPBOX_API_KEY=

Note: Never commit real .env files. Use the provided .env.example templates.

---

## Build and Release

- Android:
  - Configure signing (android/key.properties)
  - Build AAB: flutter build appbundle --release
  - Upload via Play Console (complete Data Safety and privacy policy)

- iOS:
  - Open ios/Runner.xcworkspace, set Bundle ID and signing/team
  - Archive and upload via Xcode Organizer (TestFlight/App Store)
  - Ensure ATS (HTTPS) compliance and required privacy disclosures

- Backend:
  - Set NODE_ENV=production
  - Deploy with a process manager or container orchestration
  - Configure HTTPS endpoints and CORS allowlist for the deployed frontend origins

---

## Developer Workflow Tips

- After editing pubspec.yaml, run flutter pub get; keep dependencies alphabetically sorted to satisfy lints  
- Load dotenv early: call dotenv.load() before runApp in main()  
- Swap .env files (dev/staging/prod) to change endpoints without code changes  
- Keep routes and services consistent with backend responses; validate JSON and errors

---

## Emulator Networking Quick Ref

- Android: http://10.0.2.2 maps to host 127.0.0.1 inside the emulator  
- iOS: http://localhost typically reaches the host machine’s services

---

## Troubleshooting

- Assets not loading → verify pubspec assets and run flutter clean && flutter pub get  
- Android network failures (release) → ensure INTERNET permission in AndroidManifest.xml  
- iOS blocked requests → ensure HTTPS endpoints or temporary ATS exceptions for local dev only  
- CocoaPods issues → run pod repo update and pod install in ios/  
- Backend CORS errors → add the emulator/simulator origins to CORS_ORIGINS

---

## License

See LICENSE at the repository root for usage terms and contact details.

---

## Contact

For access, licensing, or collaboration requests, contact the project owner listed in LICENSE.
