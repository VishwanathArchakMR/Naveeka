// backend/models/user.js
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: 50
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true, // keep inline unique here (remove duplicate schema.index)
      lowercase: true,
      trim: true,
      match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,})+$/, 'Please enter a valid email']
    },
    phone: {
      type: String,
      required: [true, 'Phone number is required'],
      trim: true,
      match: [/^[0-9]{10}$/, 'Please enter a valid 10-digit phone number']
    },
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: [6, 'Password must be at least 6 characters long'],
      select: false
    },
    role: {
      type: String,
      enum: ['user', 'partner', 'admin'],
      default: 'user'
    },
    profileImage: {
      type: String,
      default: null,
      trim: true
    },
    preferences: [
      {
        type: String,
        enum: ['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage']
      }
    ],
    isActive: {
      type: Boolean,
      default: true
    },
    isVerified: {
      type: Boolean,
      default: false
    },
    lastLogin: {
      type: Date // set on successful login; no default so it reflects actual logins only
    }
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true }
  }
);

// Indexes for performance
// Removed duplicate of email unique index (we already have unique: true on the field)
// userSchema.index({ email: 1 }, { unique: true });
userSchema.index({ role: 1 });
userSchema.index({ isActive: 1 });

// Virtual stats (placeholder; computed in controllers if needed)
userSchema.virtual('stats').get(function () {
  return {
    wishlistCount: 0,
    visitedCount: 0,
    reviewCount: 0
  };
});

// Pre-save hook to hash password
userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();

  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Instance: compare password
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

// Instance: generate JWT token
userSchema.methods.generateAuthToken = function () {
  return jwt.sign(
    { id: this._id, role: this.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

// Instance: get safe public profile
userSchema.methods.getPublicProfile = function () {
  const {
    _id,
    name,
    email,
    phone,
    role,
    profileImage,
    preferences,
    isActive,
    isVerified,
    lastLogin,
    createdAt,
    updatedAt
  } = this.toObject({ virtuals: true });

  return {
    _id,
    name,
    email,
    phone,
    role,
    profileImage,
    preferences,
    isActive,
    isVerified,
    lastLogin,
    createdAt,
    updatedAt
  };
};

// Static: find by email
userSchema.statics.findByEmail = function (email) {
  return this.findOne({ email: (email || '').toLowerCase() });
};

// Static: find active accounts
userSchema.statics.findActive = function () {
  return this.find({ isActive: true });
};

module.exports = mongoose.model('User', userSchema);

/*
Notes:
- Removed duplicate schema-level unique index for email to resolve the warning.
- If your DB already has redundant email indexes, clean them up:
  db.users.getIndexes()
  db.users.dropIndex('<duplicate_index_name>')
*/


