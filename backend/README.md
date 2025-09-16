# Naveeka Backend API

Backend REST API for the Naveeka travel platform — discovery, maps, activities, hotels, restaurants, trails, transport (buses, trains, flights), messaging, trip planning, and cabs — with authentication, uploads, wishlist, and admin features.

---

## 🚀 Features

- Authentication and roles
  - JWT auth with roles: user, partner, admin
  - Profile update and password change
- Discovery and search
  - Unified search endpoints and curated discovery rails
  - Nearby and bbox map queries (2dsphere)
- Places and content
  - Activities, hotels, restaurants, trails
  - Photos, reviews, availability, quotes, booking stubs
- Transport
  - Buses and bus stops, trains and stations, flights and airports
  - GTFS-like stops, serviceDays, validity, fares, routes (GeoJSON LineStrings)
- Messaging
  - Threads (dm/group), messages (text/image/location), reactions, read receipts
  - SSE-ready event payloads for live updates
- Planning
  - Trip groups with members/roles, itinerary (GeoJSON Points), expenses, checklist, documents
  - Exports: GeoJSON overlays and iCalendar (ICS)
- Cabs
  - Ride types, estimates, simple seat maps, live status stub, booking stub
- Uploads (optional)
  - Cloudinary-backed uploads if enabled
- Security
  - Helmet, CORS allowlist, rate limiting, input sanitization

---

## 🛠️ Tech Stack

- Runtime: Node.js (>= 18)
- Framework: Express.js
- Database: MongoDB (Atlas or local)
- ODM: Mongoose
- Auth: JWT (jsonwebtoken)
- Uploads: Multer + Cloudinary
- Validation: express-validator
- Security middleware:
  - helmet
  - cors
  - express-rate-limit
  - express-mongo-sanitize
  - xss-clean
- Logging: morgan
- Compression: compression

---

## 📂 Folder Structure

backend/
├── config/
│   └── database.js
├── controllers/
│   ├── authController.js
│   ├── activityController.js
│   ├── restaurantController.js
│   ├── hotelController.js
│   ├── trailController.js
│   ├── busController.js
│   ├── busStopController.js
│   ├── trainController.js
│   ├── trainStationController.js
│   ├── flightController.js
│   ├── airportController.js
│   ├── messageController.js
│   ├── planningController.js
│   ├── mapController.js
│   ├── locationController.js
│   └── cabController.js
├── middleware/
│   ├── auth.js
│   └── errorHandler.js
├── models/
│   ├── User.js
│   ├── Activity.js
│   ├── Restaurant.js
│   ├── Hotel.js
│   ├── Trail.js
│   ├── Bus.js
│   ├── BusStop.js
│   ├── Train.js
│   ├── TrainStation.js
│   ├── Flight.js
│   ├── Airport.js
│   ├── Message.js
│   ├── MessageThread.js
│   ├── ReadReceipt.js
│   ├── TripGroup.js
│   └── LocationMaster.js
├── routes/
│   ├── authRoutes.js
│   ├── activityRoutes.js
│   ├── restaurantRoutes.js
│   ├── hotelRoutes.js
│   ├── trailRoutes.js
│   ├── busRoutes.js
│   ├── busStopRoutes.js
│   ├── trainRoutes.js
│   ├── trainStationRoutes.js
│   ├── flightRoutes.js
│   ├── airportRoutes.js
│   ├── messageRoutes.js
│   ├── planningRoutes.js
│   ├── mapRoutes.js
│   ├── locationRoutes.js
│   ├── uploadRoutes.js
│   ├── userRoutes.js
│   ├── discoveryRoutes.js
│   ├── searchRoutes.js
│   └── atlasRoutes.js
├── scripts/
│   ├── seed_admin.js
│   ├── seed_regions.js
│   ├── seed_activities.js
│   ├── seed_airports.js
│   ├── seed_bus_stops.js
│   ├── seed_buses.js
│   ├── seed_flights.js
│   ├── seed_hotels.js
│   ├── seed_locations_master.js
│   ├── seed_messages.js
│   ├── seed_planning.js
│   ├── seed_restaurants.js
│   ├── seed_trails.js
│   ├── seed_train_stations.js
│   └── seed_trains.js
├── services/
│   ├── activityService.js
│   ├── restaurantService.js
│   ├── hotelService.js
│   ├── trailService.js
│   ├── busService.js
│   ├── trainService.js
│   ├── flightService.js
│   ├── cabService.js
│   ├── mapService.js
│   ├── locationService.js
│   └── messageService.js
├── server.js
├── package.json
├── .env
└── env.example

---

## ⚙️ Setup & Installation

1) Clone the repository and open backend/
2) Install dependencies:
   - npm install
3) Configure environment:
   - Copy env.example to .env and fill in values (see below)
4) Development:
   - npm run dev
5) Production:
   - npm run start:prod

Health check: GET /health returns JSON with DB state and uptime.

---

## 🔑 Environment Variables

Required:
- PORT
- MONGODB_URI
- JWT_SECRET
- JWT_EXPIRES_IN

Security:
- CORS_ORIGINS (CSV allowlist)
- RATE_LIMIT_WINDOW_MS (e.g., 900000)
- RATE_LIMIT_MAX (e.g., 200)
- FRONTEND_URL (fallback origin)

Uploads (optional):
- ENABLE_UPLOADS=true|false
- CLOUDINARY_CLOUD_NAME
- CLOUDINARY_API_KEY
- CLOUDINARY_API_SECRET

---

## 🌱 Seeding Data

Common seeds:
- npm run seed:regions
- npm run seed:locations
- npm run seed:airports
- npm run seed:activities
- npm run seed:restaurants
- npm run seed:hotels
- npm run seed:trails
- npm run seed:bus-stops
- npm run seed:buses
- npm run seed:train-stations
- npm run seed:trains
- npm run seed:flights

Messages (requires user IDs):
- npm run seed:messages -- --users=ID1,ID2,ID3

Planning (requires owner/members):
- npm run seed:planning -- --owner=OWNER_ID --members=ID2,ID3

Reset variants:
- npm run seed:reset:restaurants (each domain has a --reset script)

Demo dataset:
- npm run seed:demo

---

## 📜 API Overview

Core
- /api/auth — registration, login, profile, password
- /api/users — admin user management, stats
- /api/upload — Cloudinary-backed uploads (if enabled)
- /api/wishlist — wishlist operations
- /health — service and DB readiness

Content and maps
- /api/activities, /api/restaurants, /api/hotels, /api/trails
- /api/locations — countries, regions, cities
- /api/map — combined FeatureCollections for overlays

Transport
- /api/bus-stops, /api/buses — stops, routes, schedules, fares
- /api/train-stations, /api/trains — stations, routes, schedules, fares
- /api/airports, /api/flights — offers, routes, quotes, live-status stub

Messaging and planning
- /api/messages — threads, messages, reactions, receipts, location GeoJSON
- /api/planning — trip groups, itinerary, expenses, checklist, documents, ICS export

Cabs
- /api/cabs — ride types, estimates, routes, live status stub, booking stub

Tabs/sections
- /api/discovery, /api/search, /api/atlas

---

## 🧭 Conventions

- GeoJSON (RFC 7946):
  - All coordinates use [longitude, latitude]
  - FeatureCollection outputs for map overlays
- Geospatial:
  - 2dsphere indexes and $geoNear / $geoWithin / $geoIntersects for proximity and viewport
- Time:
  - ISO 8601 strings for timestamps (e.g., 2025-09-21T18:00:00+05:30)

---

## 🔒 Security & Hardening

- Helmet for secure headers
- CORS allowlist with credentials
- Rate limiting for abuse protection
- express-mongo-sanitize and xss-clean for input filtering
- morgan logging and compression enabled
- Graceful startup/shutdown with health checks

---

## 📡 Live Updates (SSE)

- Endpoints serving SSE should use text/event-stream, no-cache, keep-alive headers
- Periodic ping comments recommended to keep connections alive

---

## 📜 License

MIT License — © 2025 Naveeka Team
