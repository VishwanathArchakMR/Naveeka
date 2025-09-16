// C:\flutterapp\myapp\backend\controllers\hotelsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Hotel = require('../models/Hotel');
const Review = require('../models/Review');
const Booking = require('../models/booking/Booking');

// Services
const hotelService = require('../services/hotelService');           // search, availability, pricing, booking
const bookingService = require('../services/bookingService');       // generic booking orchestrator
const cacheService = require('../services/cacheService');           // optional Redis
const locationService = require('../services/locationService');     // distance calc
const mapService = require('../services/mapService');               // geojson helpers

// Helpers
const toISO = (d = new Date()) => d.toISOString();
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

function buildHotelFilter(q) {
  const {
    city,
    country,
    brand,
    stars,
    minPrice,
    maxPrice,
    rating,
    amenities,
    tags,
    propertyType,
    freeCancellation,
    freeBreakfast,
    lat,
    lng,
    radius = 0,
    q: search
  } = q;

  const filter = { isActive: { $ne: false } };

  if (search) {
    filter.$or = [
      { name: new RegExp(search, 'i') },
      { city: new RegExp(search, 'i') },
      { country: new RegExp(search, 'i') },
      { brand: new RegExp(search, 'i') },
      { tags: new RegExp(search, 'i') }
    ];
  }

  if (city) filter.city = new RegExp(city, 'i');
  if (country) filter.country = new RegExp(country, 'i');
  if (brand) filter.brand = new RegExp(brand, 'i');
  if (propertyType) filter.propertyType = new RegExp(propertyType, 'i');

  if (stars) {
    const arr = parseCSV(stars).map(Number).filter((n) => !Number.isNaN(n));
    if (arr.length) filter.stars = { $in: arr };
  }

  if (minPrice || maxPrice) {
    filter['pricing.basePrice'] = {};
    if (minPrice) filter['pricing.basePrice'].$gte = Number(minPrice);
    if (maxPrice) filter['pricing.basePrice'].$lte = Number(maxPrice);
  }

  if (rating) {
    filter['reviews.averageRating'] = { $gte: parseFloat(rating) };
  }

  if (amenities) {
    const ams = parseCSV(amenities);
    if (ams.length) filter.amenities = { $all: ams };
  }

  if (tags) {
    const tgs = parseCSV(tags);
    if (tgs.length) filter.tags = { $in: tgs };
  }

  if (freeCancellation === 'true') {
    filter['policies.freeCancellation'] = true;
  }

  if (freeBreakfast === 'true') {
    filter.amenities = filter.amenities || {};
    // allow either $all merge or simple contains
    filter.amenities.$in = (filter.amenities.$in || []).concat(['breakfast']);
  }

  // Geospatial filter
  if (lat && lng && !Number.isNaN(parseFloat(lat)) && !Number.isNaN(parseFloat(lng)) && Number(radius) > 0) {
    filter.location = {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: Number(radius) * 1000
      }
    };
  }

  return filter;
}

// GET /api/v1/hotels
exports.getHotels = asyncHandler(async (req, res) => {
  const {
    page = 1,
    limit = 24,
    sortBy = 'popularity', // price|rating|stars|distance|popularity|createdAt
    sortOrder = 'desc',
    lat,
    lng
  } = req.query;

  const filter = buildHotelFilter(req.query);

  const sort = {};
  switch (sortBy) {
    case 'price':
      sort['pricing.basePrice'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'rating':
      sort['reviews.averageRating'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'stars':
      sort.stars = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      // handled by $near if lat/lng used; fallback by popularity
      sort.popularity = -1;
      break;
    case 'createdAt':
      sort.createdAt = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'popularity':
    default:
      sort.popularity = -1;
      sort.viewCount = -1;
      sort.createdAt = -1;
      break;
  }

  const p = clamp(parseInt(page), 1, 200);
  const l = clamp(parseInt(limit), 1, 100);
  const skip = (p - 1) * l;

  const [rows, total] = await Promise.all([
    Hotel.find(filter)
      .sort(sort)
      .skip(skip)
      .limit(l)
      .select('name brand stars city country tz address location amenities policies pricing reviews tags photos popularity viewCount createdAt updatedAt')
      .lean(),
    Hotel.countDocuments(filter)
  ]);

  const uLat = parseNum(lat);
  const uLng = parseNum(lng);

  const items = rows.map((h) => {
    const out = { ...h };
    if (h?.location?.coordinates) {
      const [lngH, latH] = h.location.coordinates;
      out.geoUri = `geo:${latH},${lngH}`;
      if (uLat != null && uLng != null) {
        const distKm = locationService.calculateDistance(uLat, uLng, latH, lngH);
        out.distance = Math.round(distKm * 100) / 100;
        out.distanceUnit = 'km';
      }
    }
    return out;
  });

  const totalPages = Math.ceil(total / l);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Hotels fetched successfully', {
      hotels: items,
      pagination: {
        currentPage: p,
        totalPages,
        totalCount: total,
        limit: l,
        hasNextPage: p < totalPages,
        hasPrevPage: p > 1
      },
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/hotels/nearby?lat=&lng=&radius=&limit=&stars=&amenities=
exports.getNearbyHotels = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 10, limit = 24, stars, amenities } = req.query;
  if (!lat || !lng) throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');

  const cacheKey = `nearby_hotels:${lat}:${lng}:${radius}:${limit}:${stars || 'all'}:${amenities || 'all'}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby hotels fetched (cache)', cached));
  }

  const filter = buildHotelFilter({ lat, lng, radius, stars, amenities });
  const rows = await Hotel.find(filter)
    .limit(clamp(parseInt(limit), 1, 100))
    .select('name brand stars city country address location amenities pricing reviews')
    .lean();

  const enriched = rows.map((h) => {
    const [lngH, latH] = h.location.coordinates;
    const distKm = locationService.calculateDistance(parseFloat(lat), parseFloat(lng), latH, lngH);
    return {
      ...h,
      distance: Math.round(distKm * 100) / 100,
      distanceUnit: 'km',
      geoUri: `geo:${latH},${lngH}`
    };
  });

  const payload = {
    hotels: enriched,
    center: { lat: parseFloat(lat), lng: parseFloat(lng) },
    radiusKm: Number(radius),
    totalFound: enriched.length,
    generatedAt: toISO()
  };

  await cacheService?.set?.(cacheKey, payload, 600);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby hotels fetched', payload));
});

// GET /api/v1/hotels/suggest?q=&city=&limit=
exports.suggestHotels = asyncHandler(async (req, res) => {
  const { q = '', city = '', limit = 8 } = req.query;
  if (!q || String(q).trim().length < 2) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const lmt = Math.min(parseInt(limit), 20);
  const filter = {
    $and: [
      {
        $or: [
          { name: new RegExp(q, 'i') },
          { brand: new RegExp(q, 'i') },
          { city: new RegExp(q, 'i') }
        ]
      }
    ]
  };
  if (city) filter.$and.push({ city: new RegExp(city, 'i') });

  const suggestions = await Hotel.find(filter)
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name brand city country stars location')
    .lean();

  const mapped = suggestions.map((h) => {
    const [lngH, latH] = h?.location?.coordinates || [null, null];
    return {
      id: h._id,
      name: h.name,
      brand: h.brand || null,
      stars: h.stars || null,
      city: h.city || null,
      country: h.country || null,
      geoUri: latH && lngH ? `geo:${latH},${lngH}` : null
    };
  });

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: mapped }));
});

// GET /api/v1/hotels/:id
exports.getHotelById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { userLat, userLng, includeReviews = 'true' } = req.query;

  const hotel = await Hotel.findById(id)
    .select('-__v')
    .lean();

  if (!hotel) throw new ApiError(StatusCodes.NOT_FOUND, 'Hotel not found');

  if (hotel?.location?.coordinates) {
    const [lngH, latH] = hotel.location.coordinates;
    hotel.geoUri = `geo:${latH},${lngH}`;
    if (userLat && userLng) {
      const distKm = locationService.calculateDistance(parseFloat(userLat), parseFloat(userLng), latH, lngH);
      hotel.distance = Math.round(distKm * 100) / 100;
      hotel.distanceUnit = 'km';
    }
  }

  // Optional recent reviews
  if (includeReviews === 'true') {
    const reviews = await Review.find({ hotelId: id, isActive: true })
      .populate('userId', 'name avatar')
      .sort({ createdAt: -1 })
      .limit(10)
      .lean();
    hotel.recentReviews = reviews;
  }

  await Hotel.findByIdAndUpdate(id, { $inc: { viewCount: 1 } }).catch(() => {});

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Hotel fetched', hotel));
});

// GET /api/v1/hotels/:id/availability?checkIn=&checkOut=&rooms=&adults=&children=&currency=
exports.getAvailability = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { checkIn, checkOut, rooms = 1, adults = 2, children = 0, currency } = req.query;

  if (!checkIn || !checkOut) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'checkIn and checkOut are required');
  }

  const availability = await hotelService.getAvailability({
    hotelId: id,
    checkIn,
    checkOut,
    rooms: parseInt(rooms),
    pax: { adults: parseInt(adults), children: parseInt(children) },
    currency
  });
  // { rooms:[{roomId, name, beds, amenities, rates:[{rateId, price, currency, refundable, breakfastIncluded}]}], policies, fees, taxes }

  if (!availability) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Availability not available for the selected dates');
  }

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Availability fetched', { ...availability, generatedAt: toISO() }));
});

// POST /api/v1/hotels/:id/book
// Body: { checkIn, checkOut, rooms, pax, roomId, rateId, guest, contact, paymentMethod, specialRequests, coupon }
exports.bookHotel = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const payload = req.body || {};

  const booking = await hotelService.createBooking({
    hotelId: id,
    ...payload,
    userId: req.user?.id
  });
  // { bookingId, status, payment:{paymentUrl?,expiresAtISO?}, orderSummary, voucher }

  if (!booking) throw new ApiError(StatusCodes.INTERNAL_SERVER_ERROR, 'Failed to create hotel booking');

  return res
    .status(StatusCodes.CREATED)
    .json(new ApiResponse(StatusCodes.CREATED, 'Hotel booked', { ...booking, generatedAt: toISO() }));
});

// GET /api/v1/hotels/trending?city=&country=&limit=
exports.getTrending = asyncHandler(async (req, res) => {
  const { city, country, limit = 10 } = req.query;

  const cacheKey = `hotels:trending:${city || 'all'}:${country || 'all'}:${limit}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Trending hotels fetched (cache)', cached));
  }

  const match = { isActive: { $ne: false } };
  if (city) match.city = new RegExp(city, 'i');
  if (country) match.country = new RegExp(country, 'i');

  const rows = await Hotel.aggregate([
    { $match: match },
    {
      $addFields: {
        trendingScore: {
          $add: [
            { $multiply: ['$bookingsCount', 0.45] },
            { $multiply: ['$viewCount', 0.2] },
            { $multiply: ['$reviews.totalReviews', 0.25] },
            { $multiply: ['$reviews.averageRating', 0.1] }
          ]
        }
      }
    },
    { $sort: { trendingScore: -1 } },
    { $limit: Math.min(parseInt(limit), 50) },
    {
      $project: {
        name: 1,
        brand: 1,
        stars: 1,
        city: 1,
        country: 1,
        photos: { $slice: ['$photos', 3] },
        'pricing.basePrice': 1,
        'pricing.currency': 1,
        'reviews.averageRating': 1,
        'reviews.totalReviews': 1,
        trendingScore: 1
      }
    }
  ]);

  const payload = { hotels: rows, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 1800);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Trending hotels fetched', payload));
});

// POST /api/v1/hotels/:id/reviews
// Body: { rating, title, comment, photos[] }
exports.addReview = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { rating, title, comment, photos = [] } = req.body || {};

  if (!rating) throw new ApiError(StatusCodes.BAD_REQUEST, 'rating is required');

  // Allow review only if user completed booking
  const completed = await Booking.findOne({ userId: req.user?.id, hotelId: id, status: 'completed' }).lean();
  if (!completed) throw new ApiError(StatusCodes.FORBIDDEN, 'Review allowed only after completed stay');

  const review = await Review.create({
    userId: req.user?.id,
    hotelId: id,
    type: 'hotel',
    rating: parseFloat(rating),
    title,
    comment,
    photos
  });

  // Update aggregate rating
  await hotelService.updateHotelRating(id).catch(() => {});

  const populated = await Review.findById(review._id).populate('userId', 'name avatar').lean();

  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Review added', populated));
});

// GET /api/v1/hotels/facets?city=&country=
exports.getFacets = asyncHandler(async (req, res) => {
  const { city, country } = req.query;

  const match = { isActive: { $ne: false } };
  if (city) match.city = new RegExp(city, 'i');
  if (country) match.country = new RegExp(country, 'i');

  const [stars, amenities, priceBands] = await Promise.all([
    Hotel.aggregate([
      { $match: match },
      { $group: { _id: '$stars', count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
      { $project: { _id: 0, stars: '$_id', count: 1 } }
    ]),
    Hotel.aggregate([
      { $match: match },
      { $unwind: '$amenities' },
      { $group: { _id: '$amenities', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 50 },
      { $project: { _id: 0, amenity: '$_id', count: 1 } }
    ]),
    Hotel.aggregate([
      { $match: match },
      {
        $bucket: {
          groupBy: '$pricing.basePrice',
          boundaries: [0, 50, 100, 200, 400, 800, 1600, 1000000],
          default: '1600+',
          output: { count: { $sum: 1 } }
        }
      }
    ])
  ]);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Facets fetched', {
      stars,
      amenities,
      priceBands,
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/hotels/:id/photos?limit=&offset=
exports.getPhotos = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { limit = 20, offset = 0 } = req.query;

  const hotel = await Hotel.findById(id).select('photos gallery').lean();
  if (!hotel) throw new ApiError(StatusCodes.NOT_FOUND, 'Hotel not found');

  const recentReviewPhotos = await Review.find({ hotelId: id, photos: { $exists: true, $not: { $size: 0 } } })
    .select('photos userId createdAt')
    .populate('userId', 'name avatar')
    .sort({ createdAt: -1 })
    .limit(parseInt(limit))
    .skip(parseInt(offset))
    .lean();

  const data = {
    official: hotel.photos || [],
    gallery: hotel.gallery || [],
    userPhotos: recentReviewPhotos,
    total:
      (hotel.photos?.length || 0) +
      (hotel.gallery?.length || 0) +
      recentReviewPhotos.length
  };

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Photos fetched', data));
});

// GET /api/v1/hotels/geojson?city=&country=&lat=&lng=&radius=&limit=
exports.getHotelsGeoJSON = asyncHandler(async (req, res) => {
  const filter = buildHotelFilter(req.query);
  const { limit = 2000 } = req.query;

  const rows = await Hotel.find(filter)
    .limit(Math.min(parseInt(limit), 5000))
    .select('name brand stars city country tz location pricing reviews')
    .lean();

  const features = rows
    .filter((h) => h?.location?.coordinates && Array.isArray(h.location.coordinates))
    .map((h) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: h.location.coordinates },
      properties: {
        id: h._id,
        type: 'hotel',
        name: h.name,
        brand: h.brand || null,
        stars: h.stars || null,
        city: h.city || null,
        country: h.country || null,
        tz: h.tz || null,
        rating: h.reviews?.averageRating || null,
        price: h.pricing?.basePrice || null,
        currency: h.pricing?.currency || null,
        geo: `geo:${h.location.coordinates},${h.location.coordinates}`
      }
    }));

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});
