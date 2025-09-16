// C:\flutterapp\myapp\backend\server.js
'use strict';

require('dotenv').config();

const http = require('http');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const mongoSanitize = require('express-mongo-sanitize');
const xss = require('xss-clean');
const mongoose = require('mongoose');

// DB connection bootstrap
const connectDB = require('./config/database');

// Global error handler
const errorHandler = require('./middleware/errorHandler');

// Existing core routes
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const placeRoutes = require('./routes/placeRoutes');
const wishlistRoutes = require('./routes/wishlistRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const regionRoutes = require('./routes/regionRoutes');

// New domain routes aligned with services
const activityRoutes = require('./routes/activitiesRoutes');           // /api/activities
const airportRoutes = require('./routes/airportRoutes');             // /api/airports
const restaurantRoutes = require('./routes/restaurantRoutes');       // /api/restaurants
const hotelRoutes = require('./routes/hotelRoutes');                 // /api/hotels
const busStopRoutes = require('./routes/busStopRoutes');             // /api/bus-stops
const busRoutes = require('./routes/busRoutes');                     // /api/buses
const flightRoutes = require('./routes/flightRoutes');               // /api/flights
const trainStationRoutes = require('./routes/trainStationRoutes');   // /api/train-stations
const trainRoutes = require('./routes/trainRoutes');                 // /api/trains
const trailRoutes = require('./routes/trailRoutes');                 // /api/trails
const locationRoutes = require('./routes/locationRoutes');           // /api/locations
const mapRoutes = require('./routes/mapRoutes');                     // /api/map
const messageRoutes = require('./routes/messageRoutes');             // /api/messages
const planningRoutes = require('./routes/planningRoutes');           // /api/planning
const cabRoutes = require('./routes/cabRoutes');                     // /api/cabs

// Phase 1 tabs and legacy bundles (kept)
const discoveryRoutes = require('./routes/discoveryRoutes');         // /api/discovery
const searchRoutes = require('./routes/searchRoutes');               // /api/search
const atlasRoutes = require('./routes/atlasRoutes');                 // /api/atlas

// Trail (social)
const userSocialRoutes = require('./routes/social/userSocialRoutes');// /api/trail/profile
const postRoutes = require('./routes/social/postRoutes');            // /api/trail/posts
const feedRoutes = require('./routes/social/feedRoutes');            // /api/trail/feed

// Journey (booking skeleton)
const experienceRoutes = require('./routes/booking/experienceRoutes');// /api/journey/experiences
const bookingRoutes = require('./routes/booking/bookingRoutes');      // /api/journey/bookings

// Chat stub
const aiRoutes = require('./routes/aiRoutes');                       // /api/traveos.ai

// Optional legacy routes (lazy)
let journeyRoutes;

// Validate required env
const requiredKeys = ['PORT', 'MONGODB_URI', 'JWT_SECRET'];
for (const key of requiredKeys) {
  if (!process.env[key]) {
    console.error(`❌ Missing required environment variable: ${key}`);
    process.exit(1);
  }
}

// Uploads flag and Cloudinary keys
const uploadsEnabled = (process.env.ENABLE_UPLOADS || 'true') === 'true';
if (uploadsEnabled) {
  const cloudKeys = ['CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET'];
  for (const key of cloudKeys) {
    if (!process.env[key]) {
      console.error(`❌ Missing Cloudinary env var: ${key} (required when ENABLE_UPLOADS=true)`);
      process.exit(1);
    }
  }
}

// App
const app = express();
app.set('trust proxy', 1);

// Security and hardening
app.use(helmet()); // sensible defaults; adjust CSP per UI needs if required [ref: routes/assets] [1]
app.use(mongoSanitize()); // prevent NoSQL injection keys in payloads [1]
app.use(xss()); // basic XSS sanitization of user input [8]

// Compression and logging
app.use(compression());
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Body parsing
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

// CORS allowlist
const allowedOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
  : [process.env.FRONTEND_URL || 'http://localhost:3000'];

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
      const err = new Error(`Not allowed by CORS: ${origin}`);
      err.statusCode = 403;
      return callback(err);
    },
    credentials: true
  })
);

// Global basic rate limit
app.use(
  rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || `${15 * 60 * 1000}`, 10),
    max: parseInt(process.env.RATE_LIMIT_MAX || '200', 10),
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: 'Too many requests, please try again later.' }
  })
);

// ----------------------
// Routes
// ----------------------

// Core
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/places', placeRoutes);
app.use('/api/wishlist', wishlistRoutes);
app.use('/api/regions', regionRoutes);

// Domain (new)
app.use('/api/activities', activityRoutes);
app.use('/api/airports', airportRoutes);
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/hotels', hotelRoutes);
app.use('/api/bus-stops', busStopRoutes);
app.use('/api/buses', busRoutes);
app.use('/api/flights', flightRoutes);
app.use('/api/train-stations', trainStationRoutes);
app.use('/api/trains', trainRoutes);
app.use('/api/trails', trailRoutes);
app.use('/api/locations', locationRoutes);
app.use('/api/map', mapRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/planning', planningRoutes);
app.use('/api/cabs', cabRoutes);

// Tabs/sections retained
app.use('/api/discovery', discoveryRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/atlas', atlasRoutes);

// Social
app.use('/api/trail/profile', userSocialRoutes);
app.use('/api/trail/posts', postRoutes);
app.use('/api/trail/feed', feedRoutes);

// Booking skeleton and chat
app.use('/api/journey/experiences', experienceRoutes);
app.use('/api/journey/bookings', bookingRoutes);
app.use('/api/traveos.ai', aiRoutes);

// Uploads (optional)
if (uploadsEnabled) {
  app.use('/api/upload', uploadRoutes);
} else {
  console.log('📁 Upload routes disabled (ENABLE_UPLOADS=false)');
}

// Optional legacy journeys
try {
  // eslint-disable-next-line global-require
  journeyRoutes = require('./routes/journeyRoutes');
  app.use('/api/journeys', journeyRoutes);
} catch (e) {
  // ignore when absent
}

// Minimal SSE keep-alive channel (controllers can also implement SSE per route)
const sseClients = new Set();
app.get('/api/stream', (req, res) => {
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  res.write(': ok\n\n'); // comment line as immediate keep-alive
  sseClients.add(res);

  const ping = setInterval(() => {
    if (!res.writableEnded) res.write(': ping\n\n');
  }, 25000); // 25s ping to keep connection open

  req.on('close', () => {
    clearInterval(ping);
    sseClients.delete(res);
  });
});

// Health
app.get('/health', (req, res) => {
  const dbState = mongoose.connection.readyState; // 0,1,2,3
  res.json({
    success: true,
    status: 'OK',
    dbState,
    uptimeSec: Math.round(process.uptime())
  });
});

// 404
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// Error handler
app.use(errorHandler);

// ----------------------
// Start with graceful start/shutdown
// ----------------------
const BASE_PORT = parseInt(process.env.PORT || '3000', 10);
const server = http.createServer(app);

async function startServerWithProbe() {
  let attempt = 0;
  let port = BASE_PORT;

  while (attempt <= 10) {
    try {
      await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(port, resolve);
      });
      console.log(`✅ Server listening on ${port} (${process.env.NODE_ENV || 'development'})`);
      console.log(`🔐 CORS allowlist: ${allowedOrigins.join(', ')}`);
      break;
    } catch (err) {
      if (err && err.code === 'EADDRINUSE') {
        console.warn(`⚠️ Port ${port} in use, trying ${port + 1}...`);
        port += 1;
        attempt += 1;
        continue;
      }
      console.error('❌ Failed to bind server:', err);
      process.exit(1);
    }
  }

  if (attempt > 10) {
    console.error('❌ Unable to find a free port after multiple attempts.');
    process.exit(1);
  }

  // Graceful shutdown
  const shutdown = async (signal) => {
    try {
      console.log(`\n🛑 Received ${signal}. Shutting down gracefully...`);
      // Stop accepting new connections
      server.close(async () => {
        console.log('✅ HTTP server closed');
        try {
          await mongoose.connection.close(false);
          console.log('✅ MongoDB connection closed');
        } catch (e) {
          console.error('⚠️ Error closing MongoDB connection:', e);
        }
        process.exit(0);
      });
      // Force exit if not closed in 10s
      setTimeout(() => {
        console.warn('⚠️ Force exiting after timeout');
        process.exit(1);
      }, 10000).unref();
    } catch (err) {
      console.error('❌ Error during shutdown:', err);
      process.exit(1);
    }
  };

  ['SIGINT', 'SIGTERM', 'SIGQUIT'].forEach((sig) => {
    process.on(sig, () => shutdown(sig));
  });
}

// Bootstrap
(async () => {
  try {
    await connectDB();
    await startServerWithProbe();
  } catch (err) {
    console.error('❌ Failed to start server:', err);
    process.exit(1);
  }
})();
