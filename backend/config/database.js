// backend/config/database.js
const mongoose = require('mongoose');

const connectDB = async () => {
  // Fail fast if env key missing
  if (!process.env.MONGODB_URI) {
    console.error('❌ MONGODB_URI is not set in environment variables');
    process.exit(1);
  }

  try {
    // Production-friendly connection options
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      // Modern mongoose defaults handle these; still explicit for clarity
      maxPoolSize: parseInt(process.env.MONGO_MAX_POOL_SIZE || '20', 10),
      serverSelectionTimeoutMS: parseInt(process.env.MONGO_SERVER_SELECTION_TIMEOUT_MS || '10000', 10), // 10s
      socketTimeoutMS: parseInt(process.env.MONGO_SOCKET_TIMEOUT_MS || '45000', 10), // 45s
      // Enable retryable writes if supported by cluster (Atlas usually sets this in URI)
      // retryWrites: true, // prefer set in URI
      // wtimeoutMS: 2500,  // prefer set in URI
      autoIndex: process.env.NODE_ENV !== 'production', // turn off in prod for perf, use migrations
    });

    console.log(`✅ MongoDB Connected: ${conn.connection.host}/${conn.connection.name}`);
  } catch (error) {
    console.error(`❌ Error connecting to MongoDB: ${error.message}`);
    process.exit(1); // Stop app if DB connection fails
  }

  // Helpful connection event listeners
  mongoose.connection.on('error', (err) => {
    console.error(`MongoDB error: ${err.message}`);
  });

  mongoose.connection.on('disconnected', () => {
    console.warn('⚠️ MongoDB disconnected');
  });

  // Optional: log successful re-connect attempts
  mongoose.connection.on('reconnected', () => {
    console.log('🔁 MongoDB reconnected');
  });
};

module.exports = connectDB;

/*
APIs and MongoDB integration notes:
- This file is used by server bootstrap to establish the MongoDB connection before mounting APIs.
- No routes are defined here; all API routes continue to work once this connection succeeds.
- MongoDB URI must be provided via .env: MONGODB_URI=...
- Tunable envs (optional):
  - MONGO_MAX_POOL_SIZE (default 20)
  - MONGO_SERVER_SELECTION_TIMEOUT_MS (default 10000)
  - MONGO_SOCKET_TIMEOUT_MS (default 45000)
- In production, autoIndex is disabled for performance; create indexes via migration or on startup elsewhere if needed.
*/
