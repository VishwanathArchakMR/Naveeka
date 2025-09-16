const Activity = require('../models/Activity');
const Booking = require('../models/booking/Booking');
const Review = require('../models/review');
const { validationResult } = require('express-validator');
const { StatusCodes } = require('http-status-codes');
const geoService = require('../services/geoService');
const bookingService = require('../services/bookingService');
const activityService = require('../services/activityService');
const cacheService = require('../services/cacheService');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

class ActivitiesController {
  // GET /api/v1/activities - List activities with advanced filtering
  getAllActivities = asyncHandler(async (req, res) => {
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
          $maxDistance: radius * 1000 // Convert km to meters
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
      if (dateFrom) {
        filter['availability.dates'].$gte = new Date(dateFrom);
      }
      if (dateTo) {
        filter['availability.dates'].$lte = new Date(dateTo);
      }
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
        if (lat && lng) {
          // Distance sorting handled by $near
        } else {
          sortCriteria.createdAt = -1;
        }
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

      // Add distance to each activity if coordinates provided
      const enrichedActivities = await Promise.all(
        activities.map(async (activity) => {
          let enrichedActivity = { ...activity };

          // Calculate distance if user coordinates provided
          if (lat && lng && activity.location?.coordinates) {
            const distance = geoService.calculateDistance(
              parseFloat(lat),
              parseFloat(lng),
              activity.location.coordinates[1],
              activity.location.coordinates[0]
            );
            enrichedActivity.distance = Math.round(distance * 100) / 100; // Round to 2 decimals
            enrichedActivity.distanceUnit = 'km';
          }

          // Add availability status
          enrichedActivity.availabilityStatus = await activityService.checkAvailability(
            activity._id,
            dateFrom || new Date().toISOString().split('T')[0],
            dateTo
          );

          // Add geo URI for deep linking
          if (activity.location?.coordinates) {
            const [lng, lat] = activity.location.coordinates;
            enrichedActivity.geoUri = `geo:${lat},${lng}`;
          }

          return enrichedActivity;
        })
      );

      const totalPages = Math.ceil(totalCount / limitNumber);
      const hasNextPage = pageNumber < totalPages;
      const hasPrevPage = pageNumber > 1;

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Activities fetched successfully', {
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
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error fetching activities',
        [error.message]
      );
    }
  });

  // GET /api/v1/activities/search - Advanced search with location intelligence
  searchActivities = asyncHandler(async (req, res) => {
    const {
      query,
      location,
      lat,
      lng,
      radius = 25,
      filters = {},
      limit = 10
    } = req.body;

    if (!query && !location && !(lat && lng)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        'Search query or location is required'
      );
    }

    try {
      const searchResults = await activityService.advancedSearch({
        query,
        location: { lat: parseFloat(lat), lng: parseFloat(lng), radius },
        filters,
        limit: parseInt(limit)
      });

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Search completed successfully', {
          results: searchResults.activities,
          totalFound: searchResults.total,
          searchMeta: {
            query,
            location: location || (lat && lng ? `${lat},${lng}` : null),
            radius,
            processingTime: searchResults.processingTime
          },
          suggestions: searchResults.suggestions
        })
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error performing search',
        [error.message]
      );
    }
  });

  // GET /api/v1/activities/nearby - Get activities near user location
  getNearbyActivities = asyncHandler(async (req, res) => {
    const { lat, lng, radius = 10, limit = 20, category } = req.query;

    if (!lat || !lng) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        'Latitude and longitude are required'
      );
    }

    try {
      const cacheKey = `nearby_activities:${lat}:${lng}:${radius}:${category || 'all'}:${limit}`;
      const cachedResult = await cacheService.get(cacheKey);
      
      if (cachedResult) {
        return res.status(StatusCodes.OK).json(
          new ApiResponse(StatusCodes.OK, 'Nearby activities fetched from cache', cachedResult)
        );
      }

      const nearbyActivities = await activityService.findNearby({
        latitude: parseFloat(lat),
        longitude: parseFloat(lng),
        radius: parseFloat(radius),
        category,
        limit: parseInt(limit)
      });

      const result = {
        activities: nearbyActivities,
        center: { lat: parseFloat(lat), lng: parseFloat(lng) },
        radius: parseFloat(radius),
        totalFound: nearbyActivities.length
      };

      // Cache for 10 minutes
      await cacheService.set(cacheKey, result, 600);

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Nearby activities fetched successfully', result)
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error fetching nearby activities',
        [error.message]
      );
    }
  });

  // GET /api/v1/activities/:id - Get activity details with enhanced info
  getActivityById = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { includeReviews = 'true', userLat, userLng } = req.query;

    try {
      const activity = await Activity.findById(id)
        .populate('provider', 'name logo contactInfo verificationStatus')
        .populate('reviews', 'averageRating totalReviews')
        .lean();

      if (!activity) {
        throw new ApiError(StatusCodes.NOT_FOUND, 'Activity not found');
      }

      // Add distance if user coordinates provided
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

      // Add geo URI for deep linking
      if (activity.location?.coordinates) {
        const [lng, lat] = activity.location.coordinates;
        activity.geoUri = `geo:${lat},${lng}`;
      }

      // Get availability for next 30 days
      const availability = await activityService.getAvailabilityCalendar(
        id,
        new Date(),
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      );
      activity.availabilityCalendar = availability;

      // Get recent reviews if requested
      if (includeReviews === 'true') {
        const reviews = await Review.find({ activityId: id, isActive: true })
          .populate('userId', 'name avatar')
          .sort({ createdAt: -1 })
          .limit(10)
          .lean();
        activity.recentReviews = reviews;
      }

      // Get related activities
      const relatedActivities = await activityService.getRelatedActivities(
        id,
        activity.category,
        activity.location,
        5
      );
      activity.relatedActivities = relatedActivities;

      // Track view
      await Activity.findByIdAndUpdate(id, { $inc: { viewCount: 1 } });

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Activity details fetched successfully', activity)
      );
    } catch (error) {
      if (error.name === 'CastError') {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid activity ID format');
      }
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error fetching activity details',
        [error.message]
      );
    }
  });

  // GET /api/v1/activities/categories - Get activity categories
  getCategories = asyncHandler(async (req, res) => {
    try {
      const cacheKey = 'activity_categories';
      const cachedCategories = await cacheService.get(cacheKey);
      
      if (cachedCategories) {
        return res.status(StatusCodes.OK).json(
          new ApiResponse(StatusCodes.OK, 'Categories fetched from cache', cachedCategories)
        );
      }

      const categories = await Activity.aggregate([
        { $match: { isActive: true } },
        { $group: { _id: '$category', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        {
          $project: {
            _id: 0,
            name: '$_id',
            count: 1,
            icon: {
              $switch: {
                branches: [
                  { case: { $eq: ['$_id', 'adventure'] }, then: 'adventure_icon.svg' },
                  { case: { $eq: ['$_id', 'cultural'] }, then: 'cultural_icon.svg' },
                  { case: { $eq: ['$_id', 'nature'] }, then: 'nature_icon.svg' },
                  { case: { $eq: ['$_id', 'food'] }, then: 'food_icon.svg' },
                  { case: { $eq: ['$_id', 'entertainment'] }, then: 'entertainment_icon.svg' },
                  { case: { $eq: ['$_id', 'sports'] }, then: 'sports_icon.svg' },
                  { case: { $eq: ['$_id', 'wellness'] }, then: 'wellness_icon.svg' }
                ],
                default: 'activity_icon.svg'
              }
            }
          }
        }
      ]);

      // Cache for 1 hour
      await cacheService.set(cacheKey, categories, 3600);

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Categories fetched successfully', categories)
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error fetching categories',
        [error.message]
      );
    }
  });

  // POST /api/v1/activities/:id/book - Book an activity
  bookActivity = asyncHandler(async (req, res) => {
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
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        'Validation failed',
        errors.array()
      );
    }

    try {
      // Check activity exists and is bookable
      const activity = await Activity.findById(id);
      if (!activity) {
        throw new ApiError(StatusCodes.NOT_FOUND, 'Activity not found');
      }

      if (!activity.isActive || !activity.bookingEnabled) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Activity is not available for booking');
      }

      // Check availability
      const isAvailable = await activityService.checkAvailability(id, date, timeSlot);
      if (!isAvailable) {
        throw new ApiError(
          StatusCodes.CONFLICT,
          'Selected date and time is not available'
        );
      }

      // Calculate pricing
      const pricing = await activityService.calculatePricing(
        id,
        participants,
        date,
        timeSlot
      );

      // Create booking
      const bookingData = {
        userId: req.user.id,
        activityId: id,
        type: 'activity',
        date: new Date(date),
        timeSlot,
        participants: {
          adults: participants.adults || 1,
          children: participants.children || 0,
          infants: participants.infants || 0,
          total: participants.total || participants.adults + participants.children
        },
        contactInfo,
        specialRequests,
        pricing,
        status: 'pending_payment',
        bookingReference: `ACT${Date.now()}${Math.random().toString(36).substr(2, 5).toUpperCase()}`,
        metadata: {
          activityName: activity.name,
          provider: activity.provider,
          location: activity.location,
          category: activity.category
        }
      };

      const booking = await bookingService.createBooking(bookingData, paymentMethod);

      // Send booking confirmation
      await activityService.sendBookingNotification(booking, 'created');

      return res.status(StatusCodes.CREATED).json(
        new ApiResponse(StatusCodes.CREATED, 'Activity booked successfully', {
          booking,
          paymentUrl: booking.paymentUrl,
          expiresAt: booking.paymentExpiresAt
        })
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error booking activity',
        [error.message]
      );
    }
  });

  // GET /api/v1/activities/:id/availability - Get activity availability
  getActivityAvailability = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { startDate, endDate, participants } = req.query;

    try {
      const activity = await Activity.findById(id);
      if (!activity) {
        throw new ApiError(StatusCodes.NOT_FOUND, 'Activity not found');
      }

      const start = startDate ? new Date(startDate) : new Date();
      const end = endDate ? new Date(endDate) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

      const availability = await activityService.getDetailedAvailability(
        id,
        start,
        end,
        participants ? parseInt(participants) : 1
      );

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Availability fetched successfully', {
          availability,
          activity: {
            id: activity._id,
            name: activity.name,
            maxParticipants: activity.capacity.maxParticipants,
            duration: activity.duration
          },
          dateRange: { startDate: start, endDate: end }
        })
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error fetching availability',
        [error.message]
      );
    }
  });

  // POST /api/v1/activities/:id/reviews - Add activity review
  addReview = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { rating, comment, photos } = req.body;

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        'Validation failed',
        errors.array()
      );
    }

    try {
      // Check if user has booked this activity
      const hasBooking = await Booking.findOne({
        userId: req.user.id,
        activityId: id,
        status: 'completed'
      });

      if (!hasBooking) {
        throw new ApiError(
          StatusCodes.FORBIDDEN,
          'You can only review activities you have completed'
        );
      }

      // Check if user has already reviewed this activity
      const existingReview = await Review.findOne({
        userId: req.user.id,
        activityId: id
      });

      if (existingReview) {
        throw new ApiError(
          StatusCodes.CONFLICT,
          'You have already reviewed this activity'
        );
      }

      const review = new Review({
        userId: req.user.id,
        activityId: id,
        type: 'activity',
        rating: parseFloat(rating),
        comment,
        photos: photos || [],
        bookingId: hasBooking._id
      });

      await review.save();

      // Update activity rating
      await activityService.updateActivityRating(id);

      const populatedReview = await Review.findById(review._id)
        .populate('userId', 'name avatar')
        .lean();

      return res.status(StatusCodes.CREATED).json(
        new ApiResponse(StatusCodes.CREATED, 'Review added successfully', populatedReview)
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error adding review',
        [error.message]
      );
    }
  });

  // GET /api/v1/activities/:id/photos - Get activity photos
  getActivityPhotos = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { limit = 20, offset = 0 } = req.query;

    try {
      const activity = await Activity.findById(id).select('photos gallery');
      if (!activity) {
        throw new ApiError(StatusCodes.NOT_FOUND, 'Activity not found');
      }

      // Combine activity photos and user-uploaded photos from reviews
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

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Activity photos fetched successfully', allPhotos)
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error fetching activity photos',
        [error.message]
      );
    }
  });

  // GET /api/v1/activities/trending - Get trending activities
  getTrendingActivities = asyncHandler(async (req, res) => {
    const { limit = 10, location, category } = req.query;

    try {
      const cacheKey = `trending_activities:${location || 'global'}:${category || 'all'}:${limit}`;
      const cachedResult = await cacheService.get(cacheKey);
      
      if (cachedResult) {
        return res.status(StatusCodes.OK).json(
          new ApiResponse(StatusCodes.OK, 'Trending activities fetched from cache', cachedResult)
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
                { $multiply: ['$bookingCount', 0.4] },
                { $multiply: ['$viewCount', 0.2] },
                { $multiply: ['$reviews.totalReviews', 0.3] },
                { $multiply: ['$reviews.averageRating', 0.1] }
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

      // Cache for 30 minutes
      await cacheService.set(cacheKey, result, 1800);

      return res.status(StatusCodes.OK).json(
        new ApiResponse(StatusCodes.OK, 'Trending activities fetched successfully', result)
      );
    } catch (error) {
      throw new ApiError(
        StatusCodes.INTERNAL_SERVER_ERROR,
        'Error fetching trending activities',
        [error.message]
      );
    }
  });
}

module.exports = new ActivitiesController();
