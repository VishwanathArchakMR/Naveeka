// C:\app\Naveeka\backend\server.js
'use strict';

require('dotenv').config();

const path = require('path');
const http = require('http');
const fs = require('fs');
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

// Core routes (expected to exist)
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const placeRoutes = require('./routes/placeRoutes');
const wishlistRoutes = require('./routes/wishlistRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const regionRoutes = require('./routes/regionRoutes');

// Safe route mounting helper: only mount if the file exists and resolves cleanly
function mountIfExists(app, urlPath, relModulePath) {
  const resolvedPath = path.join(__dirname, relModulePath);
  try {
    // If module cannot be resolved, skip mounting
    require.resolve(resolvedPath); // throws MODULE_NOT_FOUND if absent
    // Require after resolve so nested errors surface properly
    // eslint-disable-next-line global-require, import/no-dynamic-require
    const router = require(resolvedPath);
    if (router && typeof router === 'function') {
      app.use(urlPath, router);
      console.log(`✅ Mounted ${urlPath} -> ${relModulePath}`);
    } else {
      console.warn(`⚠️ Route module does not export a router function: ${relModulePath}`);
    }
  } catch (e) {
    if (e && e.code === 'MODULE_NOT_FOUND') {
      console.warn(`ℹ️ Skipping missing route: ${relModulePath}`);
    } else {
      console.error(`❌ Failed to load route ${relModulePath}:`, e);
    }
  }
}

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
app.use(helmet());
app.use(mongoSanitize());
app.use(xss());

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
    credentials: true,
  })
);

// Global basic rate limit
app.use(
  rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || `${15 * 60 * 1000}`, 10),
    max: parseInt(process.env.RATE_LIMIT_MAX || '200', 10),
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: 'Too many requests, please try again later.' },
  })
);

// ----------------------
// Routes
// ----------------------

// Core (expected to exist)
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/places', placeRoutes);
app.use('/api/wishlist', wishlistRoutes);
app.use('/api/regions', regionRoutes);

// Uploads (optional)
if (uploadsEnabled) {
  app.use('/api/upload', uploadRoutes);
} else {
  console.log('📁 Upload routes disabled (ENABLE_UPLOADS=false)');
}

// Domain (conditionally mounted to avoid MODULE_NOT_FOUND)
mountIfExists(app, '/api/activities', './routes/activitiesRoutes');
mountIfExists(app, '/api/airports', './routes/airportRoutes');
mountIfExists(app, '/api/restaurants', './routes/restaurantRoutes');
mountIfExists(app, '/api/hotels', './routes/hotelRoutes');
mountIfExists(app, '/api/bus-stops', './routes/busStopRoutes');
mountIfExists(app, '/api/buses', './routes/busRoutes');
mountIfExists(app, '/api/flights', './routes/flightRoutes');
mountIfExists(app, '/api/train-stations', './routes/trainStationRoutes');
mountIfExists(app, '/api/trains', './routes/trainRoutes');
mountIfExists(app, '/api/trails', './routes/trailRoutes');
mountIfExists(app, '/api/locations', './routes/locationRoutes');
mountIfExists(app, '/api/map', './routes/mapRoutes');
mountIfExists(app, '/api/messages', './routes/messageRoutes');
mountIfExists(app, '/api/planning', './routes/planningRoutes');
mountIfExists(app, '/api/cabs', './routes/cabRoutes');

// Tabs/sections retained
mountIfExists(app, '/api/discovery', './routes/discoveryRoutes');
mountIfExists(app, '/api/search', './routes/searchRoutes');
mountIfExists(app, '/api/atlas', './routes/atlasRoutes');

// Social
mountIfExists(app, '/api/trail/profile', './routes/social/userSocialRoutes');
mountIfExists(app, '/api/trail/posts', './routes/social/postRoutes');
mountIfExists(app, '/api/trail/feed', './routes/social/feedRoutes');

// Booking skeleton and chat
mountIfExists(app, '/api/journey/experiences', './routes/booking/experienceRoutes');
mountIfExists(app, '/api/journey/bookings', './routes/booking/bookingRoutes');
mountIfExists(app, '/api/traveos.ai', './routes/aiRoutes');

// Optional legacy journeys
mountIfExists(app, '/api/journeys', './routes/journeyRoutes');

// Minimal SSE keep-alive channel
const sseClients = new Set();
app.get('/api/stream', (req, res) => {
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  res.write(': ok\n\n'); // immediate keep-alive
  sseClients.add(res);

  const ping = setInterval(() => {
    if (!res.writableEnded) res.write(': ping\n\n');
  }, 25000);

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
    uptimeSec: Math.round(process.uptime()),
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
