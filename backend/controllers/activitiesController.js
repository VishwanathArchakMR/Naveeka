// C:\app\Naveeka\backend\controllers\activitiesController.js

const Activity = require('../models/Activity');
const Booking = require('../models/booking/Booking');
const Review = require('../models/review');
const { validationResult } = require('express-validator');
const { StatusCodes } = require('http-status-codes');
const geoService = require('../services/locationService');
const bookingService = require('../services/bookingService'); // kept for future use
const activityService = require('../services/activityService');
const { cacheService } = require('../services/cacheService');
const { ApiError } = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');

// GET /api/v1/activities - List activities with advanced filtering
async function getActivities(req, res) {
  const {
    page = 1,
    limit = 20,
    category,
    location,
    lat,
    lng,
    radius = 50,
    minPrice,
    maxPrice,
    rating,
    duration,
    difficulty,
    language,
    dateFrom,
    dateTo,
    sortBy = 'popularity',
    sortOrder = 'desc',
    search,
    tags
  } = req.query;

  // Build filter query
  const filter = {};

  // Category filter
  if (category) {
    filter.category = { $in: category.split(',') };
  }

  // Location-based filtering
  if (lat && lng) {
    const coordinates = [parseFloat(lng), parseFloat(lat)];
    filter.location = {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: coordinates
        },
        $maxDistance: Number(radius) * 1000 // km -> meters
      }
    };
  } else if (location) {
    filter['address.city'] = new RegExp(location, 'i');
  }

  // Price range filter
  if (minPrice || maxPrice) {
    filter['pricing.basePrice'] = {};
    if (minPrice) filter['pricing.basePrice'].$gte = parseFloat(minPrice);
    if (maxPrice) filter['pricing.basePrice'].$lte = parseFloat(maxPrice);
  }

  // Rating filter
  if (rating) {
    filter['reviews.averageRating'] = { $gte: parseFloat(rating) };
  }

  // Duration filter
  if (duration) {
    const durationRanges = duration.split(',');
    filter.$or = durationRanges.map(range => {
      switch (range) {
        case 'short': return { 'duration.hours': { $lte: 3 } };
        case 'medium': return { 'duration.hours': { $gte: 3, $lte: 8 } };
        case 'long': return { 'duration.hours': { $gt: 8 } };
        default: return {};
      }
    });
  }

  // Difficulty filter
  if (difficulty) {
    filter.difficulty = { $in: difficulty.split(',') };
  }

  // Language filter
  if (language) {
    filter.languages = { $in: language.split(',') };
  }

  // Availability date filter
  if (dateFrom || dateTo) {
    filter['availability.dates'] = {};
    if (dateFrom) filter['availability.dates'].$gte = new Date(dateFrom);
    if (dateTo) filter['availability.dates'].$lte = new Date(dateTo);
  }

  // Text search
  if (search) {
    filter.$text = { $search: search };
  }

  // Tags filter
  if (tags) {
    filter.tags = { $in: tags.split(',') };
  }

  // Active activities only
  filter.isActive = true;

  // Build sort criteria
  const sortCriteria = {};
  switch (sortBy) {
    case 'price':
      sortCriteria['pricing.basePrice'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'rating':
      sortCriteria['reviews.averageRating'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'duration':
      sortCriteria['duration.hours'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      if (!lat || !lng) sortCriteria.createdAt = -1;
      break;
    case 'popularity':
      sortCriteria.bookingCount = -1;
      sortCriteria['reviews.totalReviews'] = -1;
      break;
    default:
      sortCriteria.createdAt = -1;
  }

  const pageNumber = parseInt(page);
  const limitNumber = parseInt(limit);
  const skip = (pageNumber - 1) * limitNumber;

  try {
    const [activities, totalCount] = await Promise.all([
      Activity.find(filter)
        .sort(sortCriteria)
        .skip(skip)
        .limit(limitNumber)
        .populate('reviews', 'averageRating totalReviews')
        .populate('provider', 'name logo contactInfo')
        .select('-__v -updatedAt')
        .lean(),
      Activity.countDocuments(filter)
    ]);

    // Add distance and enrich per item
    const enrichedActivities = await Promise.all(
      activities.map(async (activity) => {
        const enriched = { ...activity };

        // Distance if coordinates provided
        if (lat && lng && activity.location?.coordinates) {
          const distance = geoService.calculateDistance(
            parseFloat(lat),
            parseFloat(lng),
            activity.location.coordinates[1],
            activity.location.coordinates[0]
          );
          enriched.distance = Math.round(distance * 100) / 100;
          enriched.distanceUnit = 'km';
        }

        // Availability quick status (if service present)
        if (activityService?.checkAvailability) {
          enriched.availabilityStatus = await activityService.checkAvailability(
            activity._id,
            dateFrom || new Date().toISOString().split('T')[0],
            dateTo
          );
        }

        // geo: URI
        if (activity.location?.coordinates) {
          const [lngV, latV] = activity.location.coordinates;
          enriched.geoUri = `geo:${latV},${lngV}`;
        }

        return enriched;
      })
    );

    const totalPages = Math.ceil(totalCount / limitNumber);
    const hasNextPage = pageNumber < totalPages;
    const hasPrevPage = pageNumber > 1;

    return res.status(StatusCodes.OK).json(
      ApiResponse.success({
        activities: enrichedActivities,
        pagination: {
          currentPage: pageNumber,
          totalPages,
          totalCount,
          hasNextPage,
          hasPrevPage,
          limit: limitNumber
        },
        filters: {
          category,
          location: location || (lat && lng ? `${lat},${lng}` : null),
          priceRange: { min: minPrice, max: maxPrice },
          rating,
          duration,
          difficulty,
          language
        }
      })
    );
  } catch (error) {
    throw new ApiError('Error fetching activities', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'ACTIVITIES_LIST_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/nearby
async function getNearbyActivities(req, res) {
  const { lat, lng, radius = 10, limit = 20, category } = req.query;

  if (!lat || !lng) {
    throw ApiError.badRequest('Latitude and longitude are required');
  }

  try {
    const cacheKey = `nearby_activities:${lat}:${lng}:${radius}:${category || 'all'}:${limit}`;
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.status(StatusCodes.OK).json(
        ApiResponse.success(cached, { source: 'cache' })
      );
    }

    const nearby = await activityService?.findNearby?.({
      latitude: parseFloat(lat),
      longitude: parseFloat(lng),
      radius: parseFloat(radius),
      category,
      limit: parseInt(limit)
    }) || [];

    const result = {
      activities: nearby,
      center: { lat: parseFloat(lat), lng: parseFloat(lng) },
      radius: parseFloat(radius),
      totalFound: nearby.length
    };

    await cacheService.set(cacheKey, result, 600); // 10 minutes

    return res.status(StatusCodes.OK).json(ApiResponse.success(result));
  } catch (error) {
    throw new ApiError('Error fetching nearby activities', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'NEARBY_FETCH_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/suggest
async function suggestActivities(req, res) {
  const { q, limit = 10 } = req.query;

  if (!q || q.trim().length < 2) {
    return res.json(ApiResponse.success({ suggestions: [] }));
  }

  try {
    const suggestions = await Activity.find({
      $or: [
        { name: new RegExp(q, 'i') },
        { category: new RegExp(q, 'i') },
        { tags: { $in: [new RegExp(q, 'i')] } }
      ],
      isActive: true
    })
      .select('name category photos')
      .limit(parseInt(limit))
      .lean();

    return res.json(ApiResponse.success({ suggestions }));
  } catch (error) {
    throw new ApiError('Error fetching suggestions', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'SUGGESTIONS_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/trending
async function getTrending(req, res) {
  const { limit = 10, location, category } = req.query;

  try {
    const cacheKey = `trending_activities:${location || 'global'}:${category || 'all'}:${limit}`;
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.status(StatusCodes.OK).json(
        ApiResponse.success(cached, { source: 'cache' })
      );
    }

    const matchStage = { isActive: true };
    if (category) matchStage.category = category;
    if (location) matchStage['address.city'] = new RegExp(location, 'i');

    const trendingActivities = await Activity.aggregate([
      { $match: matchStage },
      {
        $addFields: {
          trendingScore: {
            $add: [
              { $multiply: [{ $ifNull: ['$bookingCount', 0] }, 0.4] },
              { $multiply: [{ $ifNull: ['$viewCount', 0] }, 0.2] },
              { $multiply: [{ $ifNull: ['$reviews.totalReviews', 0] }, 0.3] },
              { $multiply: [{ $ifNull: ['$reviews.averageRating', 0] }, 0.1] }
            ]
          }
        }
      },
      { $sort: { trendingScore: -1 } },
      { $limit: parseInt(limit) },
      {
        $project: {
          name: 1,
          category: 1,
          photos: { $slice: ['$photos', 3] },
          'pricing.basePrice': 1,
          'pricing.currency': 1,
          'reviews.averageRating': 1,
          'reviews.totalReviews': 1,
          'address.city': 1,
          'address.country': 1,
          duration: 1,
          trendingScore: 1,
          bookingCount: 1
        }
      }
    ]);

    const result = {
      activities: trendingActivities,
      filters: { location, category },
      generatedAt: new Date().toISOString()
    };

    await cacheService.set(cacheKey, result, 1800); // 30 minutes

    return res.status(StatusCodes.OK).json(ApiResponse.success(result));
  } catch (error) {
    throw new ApiError('Error fetching trending activities', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'TRENDING_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/facets
async function getFacets(req, res) {
  try {
    const facets = await Activity.aggregate([
      { $match: { isActive: true } },
      {
        $group: {
          _id: null,
          categories: { $addToSet: '$category' },
          difficulties: { $addToSet: '$difficulty' },
          languages: { $addToSet: { $arrayElemAt: ['$languages', 0] } },
          priceRange: {
            $push: {
              min: { $min: '$pricing.basePrice' },
              max: { $max: '$pricing.basePrice' }
            }
          }
        }
      }
    ]);

    const result = facets[0] || {
      categories: [],
      difficulties: [],
      languages: [],
      priceRange: [{ min: 0, max: 1000 }]
    };

    return res.json(ApiResponse.success(result));
  } catch (error) {
    throw new ApiError('Error fetching facets', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'FACETS_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/geojson
async function getActivitiesGeoJSON(req, res) {
  const { bbox, category, limit = 100 } = req.query;

  try {
    const filter = { isActive: true, 'location.coordinates': { $exists: true } };

    if (category) filter.category = category;

    if (bbox) {
      const [minLng, minLat, maxLng, maxLat] = bbox.split(',').map(parseFloat);
      filter.location = {
        $geoWithin: {
          $box: [[minLng, minLat], [maxLng, maxLat]]
        }
      };
    }

    const activities = await Activity.find(filter)
      .select('name category location pricing photos')
      .limit(parseInt(limit))
      .lean();

    const featureCollection = {
      type: 'FeatureCollection',
      features: activities.map(activity => ({
        type: 'Feature',
        geometry: activity.location,
        properties: {
          id: activity._id,
          name: activity.name,
          category: activity.category,
          price: activity.pricing?.basePrice,
          currency: activity.pricing?.currency,
          photo: activity.photos?.[0]
        }
      }))
    };

    return res.json(ApiResponse.success(featureCollection));
  } catch (error) {
    throw new ApiError('Error fetching GeoJSON', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'GEOJSON_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/:id
async function getActivityById(req, res) {
  const { id } = req.params;
  const { includeReviews = 'true', userLat, userLng } = req.query;

  try {
    const activity = await Activity.findById(id)
      .populate('provider', 'name logo contactInfo verificationStatus')
      .lean();

    if (!activity) {
      throw ApiError.notFound('Activity not found');
    }

    // Distance
    if (userLat && userLng && activity.location?.coordinates) {
      const distance = geoService.calculateDistance(
        parseFloat(userLat),
        parseFloat(userLng),
        activity.location.coordinates[1],
        activity.location.coordinates[0]
      );
      activity.distance = Math.round(distance * 100) / 100;
      activity.distanceUnit = 'km';
    }

    // geo: URI
    if (activity.location?.coordinates) {
      const [lngV, latV] = activity.location.coordinates;
      activity.geoUri = `geo:${latV},${lngV}`;
    }

    // Recent reviews
    if (includeReviews === 'true') {
      const reviews = await Review.find({ activityId: id, isActive: true })
        .populate('userId', 'name avatar')
        .sort({ createdAt: -1 })
        .limit(10)
        .lean();
      activity.recentReviews = reviews;
    }

    // Track view
    await Activity.findByIdAndUpdate(id, { $inc: { viewCount: 1 } });

    return res.status(StatusCodes.OK).json(ApiResponse.success(activity));
  } catch (error) {
    if (error.name === 'CastError') {
      throw ApiError.badRequest('Invalid activity ID format');
    }
    throw new ApiError('Error fetching activity details', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'ACTIVITY_FETCH_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/:id/availability
async function getAvailability(req, res) {
  const { id } = req.params;
  const { startDate, endDate, participants } = req.query;

  try {
    const activity = await Activity.findById(id);
    if (!activity) {
      throw ApiError.notFound('Activity not found');
    }

    const start = startDate ? new Date(startDate) : new Date();
    const end = endDate ? new Date(endDate) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    // Placeholder availability structure
    const availability = {
      available: true,
      timeSlots: ['09:00', '14:00', '16:00'],
      capacity: activity.capacity?.maxParticipants || 10
    };

    return res.status(StatusCodes.OK).json(
      ApiResponse.success({
        availability,
        activity: {
          id: activity._id,
          name: activity.name,
          maxParticipants: activity.capacity?.maxParticipants || 10,
          duration: activity.duration
        },
        dateRange: { startDate: start, endDate: end }
      })
    );
  } catch (error) {
    throw new ApiError('Error fetching availability', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'AVAILABILITY_FAILED',
      details: [error.message],
    });
  }
}

// POST /api/v1/activities/:id/book
async function bookActivity(req, res) {
  const { id } = req.params;
  const {
    date,
    timeSlot,
    participants,
    contactInfo,
    specialRequests,
    paymentMethod
  } = req.body;

  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw ApiError.badRequest('Validation failed', errors.array());
  }

  try {
    const activity = await Activity.findById(id);
    if (!activity) {
      throw ApiError.notFound('Activity not found');
    }

    if (!activity.isActive) {
      throw ApiError.badRequest('Activity is not available for booking');
    }

    const bookingReference = `ACT${Date.now()}${Math.random().toString(36).substr(2, 5).toUpperCase()}`;

    const booking = {
      userId: req.user?.id || 'guest',
      activityId: id,
      type: 'activity',
      date: new Date(date),
      timeSlot,
      participants: {
        adults: participants?.adults || 1,
        children: participants?.children || 0,
        total: participants?.total || 1
      },
      contactInfo,
      specialRequests,
      status: 'confirmed',
      bookingReference,
      metadata: {
        activityName: activity.name,
        location: activity.location,
        category: activity.category
      },
      _id: Date.now().toString(),
      createdAt: new Date()
    };

    return res.status(StatusCodes.CREATED).json(
      ApiResponse.success(booking, { message: 'Activity booked successfully' })
    );
  } catch (error) {
    throw new ApiError('Error booking activity', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'BOOKING_FAILED',
      details: [error.message],
    });
  }
}

// POST /api/v1/activities/:id/reviews
async function addReview(req, res) {
  const { id } = req.params;
  const { rating, comment, photos } = req.body;

  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw ApiError.badRequest('Validation failed', errors.array());
  }

  try {
    const activity = await Activity.findById(id);
    if (!activity) {
      throw ApiError.notFound('Activity not found');
    }

    const review = new Review({
      userId: req.user?.id || 'guest',
      activityId: id,
      type: 'activity',
      rating: parseFloat(rating),
      comment,
      photos: photos || []
    });

    await review.save();

    const populated = await Review.findById(review._id)
      .populate('userId', 'name avatar')
      .lean();

    return res.status(StatusCodes.CREATED).json(
      ApiResponse.success(populated, { message: 'Review added successfully' })
    );
  } catch (error) {
    throw new ApiError('Error adding review', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'REVIEW_ADD_FAILED',
      details: [error.message],
    });
  }
}

// GET /api/v1/activities/:id/photos
async function getPhotos(req, res) {
  const { id } = req.params;
  const { limit = 20, offset = 0 } = req.query;

  try {
    const activity = await Activity.findById(id).select('photos gallery');
    if (!activity) {
      throw ApiError.notFound('Activity not found');
    }

    const reviewPhotos = await Review.find({
      activityId: id,
      photos: { $exists: true, $not: { $size: 0 } }
    })
      .populate('userId', 'name avatar')
      .select('photos userId createdAt')
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(offset));

    const allPhotos = {
      official: activity.photos || [],
      gallery: activity.gallery || [],
      userPhotos: reviewPhotos,
      total: (activity.photos?.length || 0) + (activity.gallery?.length || 0) + reviewPhotos.length
    };

    return res.status(StatusCodes.OK).json(ApiResponse.success(allPhotos));
  } catch (error) {
    throw new ApiError('Error fetching activity photos', {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      code: 'PHOTOS_FETCH_FAILED',
      details: [error.message],
    });
  }
}

module.exports = {
  getActivities,
  getNearbyActivities,
  suggestActivities,
  getTrending,
  getFacets,
  getActivitiesGeoJSON,
  getActivityById,
  getAvailability,
  bookActivity,
  addReview,
  getPhotos,
};
