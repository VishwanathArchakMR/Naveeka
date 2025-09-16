// C:\flutterapp\myapp\backend\controllers\restaurantsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Restaurant = require('../models/Restaurant');
const Review = require('../models/Review');
const Booking = require('../models/booking/Booking');

// Services
const restaurantService = require('../services/restaurantService');   // search, availability, pricing, booking, menus
const bookingService = require('../services/bookingService');         // generic booking orchestrator
const cacheService = require('../services/cacheService');             // optional Redis
const locationService = require('../services/locationService');       // distance calc
const mapService = require('../services/mapService');                 // geojson helpers

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601 UTC
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

// Build MongoDB filter from query
function buildRestaurantFilter(q) {
  const {
    q: search,
    city,
    country,
    cuisines,
    priceLevel,            // $, $$, $$$, $$$$
    minPrice,
    maxPrice,
    rating,
    dietary,               // csv: vegan,vegetarian,halal,kosher,gluten_free
    features,              // csv: delivery,takeaway,reservations,outdoor_seating,live_music
    openNow,               // 'true'
    lat,
    lng,
    radius = 0,
    tags
  } = q;

  const filter = { isActive: { $ne: false } };

  if (search) {
    filter.$or = [
      { name: new RegExp(search, 'i') },
      { city: new RegExp(search, 'i') },
      { country: new RegExp(search, 'i') },
      { cuisines: new RegExp(search, 'i') },
      { tags: new RegExp(search, 'i') }
    ];
  }

  if (city) filter.city = new RegExp(city, 'i');
  if (country) filter.country = new RegExp(country, 'i');

  if (cuisines) {
    const arr = parseCSV(cuisines);
    if (arr.length) filter.cuisines = { $in: arr };
  }

  if (priceLevel) {
    const arr = parseCSV(priceLevel);
    if (arr.length) filter.priceLevel = { $in: arr };
  }

  if (minPrice || maxPrice) {
    filter['price.estimate'] = {};
    if (minPrice) filter['price.estimate'].$gte = Number(minPrice);
    if (maxPrice) filter['price.estimate'].$lte = Number(maxPrice);
  }

  if (rating) {
    filter['reviews.averageRating'] = { $gte: parseFloat(rating) };
  }

  if (dietary) {
    const d = parseCSV(dietary);
    if (d.length) filter.dietaryOptions = { $all: d };
  }

  if (features) {
    const f = parseCSV(features);
    if (f.length) filter.features = { $all: f };
  }

  if (tags) {
    const t = parseCSV(tags);
    if (t.length) filter.tags = { $in: t };
  }

  if (openNow === 'true') {
    // Expect service to add dynamic filter or precomputed "openNow" flag
    filter.openNow = true;
  }

  // Geospatial
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

// GET /api/v1/restaurants
// Query with filters, pagination, sorting, optional distance enrichment
exports.getRestaurants = asyncHandler(async (req, res) => {
  const {
    page = 1,
    limit = 24,
    sortBy = 'popularity', // rating|price|priceLevel|distance|popularity|createdAt
    sortOrder = 'desc',
    lat,
    lng
  } = req.query;

  const filter = buildRestaurantFilter(req.query);

  const sort = {};
  switch (sortBy) {
    case 'rating':
      sort['reviews.averageRating'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'price':
      sort['price.estimate'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'priceLevel':
      sort.priceLevel = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      // handled by $near if lat/lng provided; fallback:
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
  }

  const p = clamp(parseInt(page), 1, 200);
  const l = clamp(parseInt(limit), 1, 100);
  const skip = (p - 1) * l;

  const [rows, total] = await Promise.all([
    Restaurant.find(filter)
      .sort(sort)
      .skip(skip)
      .limit(l)
      .select('name city country tz address location cuisines price priceLevel dietaryOptions features tags photos reviews popularity viewCount createdAt updatedAt openNow')
      .lean(),
    Restaurant.countDocuments(filter)
  ]);

  const uLat = parseNum(lat);
  const uLng = parseNum(lng);

  const items = rows.map((r) => {
    const out = { ...r };
    if (r?.location?.coordinates) {
      const [lngR, latR] = r.location.coordinates;
      out.geoUri = `geo:${latR},${lngR}`;
      if (uLat != null && uLng != null) {
        const distKm = locationService.calculateDistance(uLat, uLng, latR, lngR);
        out.distance = Math.round(distKm * 100) / 100;
        out.distanceUnit = 'km';
      }
    }
    return out;
  });

  const totalPages = Math.ceil(total / l);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Restaurants fetched successfully', {
      restaurants: items,
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

// GET /api/v1/restaurants/nearby?lat=&lng=&radius=&limit=&cuisines=
exports.getNearbyRestaurants = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 5, limit = 24, cuisines } = req.query;
  if (!lat || !lng) throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');

  const cacheKey = `nearby_restaurants:${lat}:${lng}:${radius}:${limit}:${cuisines || 'all'}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby restaurants fetched (cache)', cached));
  }

  const filter = buildRestaurantFilter({ lat, lng, radius, cuisines });
  const rows = await Restaurant.find(filter)
    .limit(clamp(parseInt(limit), 1, 100))
    .select('name city country location cuisines price priceLevel reviews openNow')
    .lean();

  const enriched = rows.map((r) => {
    const [lngR, latR] = r.location.coordinates;
    const distKm = locationService.calculateDistance(parseFloat(lat), parseFloat(lng), latR, lngR);
    return {
      ...r,
      distance: Math.round(distKm * 100) / 100,
      distanceUnit: 'km',
      geoUri: `geo:${latR},${lngR}`
    };
  });

  const payload = {
    restaurants: enriched,
    center: { lat: parseFloat(lat), lng: parseFloat(lng) },
    radiusKm: Number(radius),
    totalFound: enriched.length,
    generatedAt: toISO()
  };

  await cacheService?.set?.(cacheKey, payload, 600);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby restaurants fetched', payload));
});

// GET /api/v1/restaurants/suggest?q=&city=&limit=
exports.suggestRestaurants = asyncHandler(async (req, res) => {
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
          { city: new RegExp(q, 'i') },
          { cuisines: new RegExp(q, 'i') }
        ]
      }
    ]
  };
  if (city) filter.$and.push({ city: new RegExp(city, 'i') });

  const suggestions = await Restaurant.find(filter)
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name city country cuisines location priceLevel')
    .lean();

  const mapped = suggestions.map((r) => {
    const [lngR, latR] = r?.location?.coordinates || [null, null];
    return {
      id: r._id,
      name: r.name,
      city: r.city || null,
      country: r.country || null,
      cuisines: r.cuisines || [],
      priceLevel: r.priceLevel || null,
      geoUri: latR && lngR ? `geo:${latR},${lngR}` : null
    };
  });

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: mapped }));
});

// GET /api/v1/restaurants/:id
exports.getRestaurantById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { userLat, userLng, includeReviews = 'true' } = req.query;

  const restaurant = await Restaurant.findById(id).select('-__v').lean();
  if (!restaurant) throw new ApiError(StatusCodes.NOT_FOUND, 'Restaurant not found');

  if (restaurant?.location?.coordinates) {
    const [lngR, latR] = restaurant.location.coordinates;
    restaurant.geoUri = `geo:${latR},${lngR}`;
    if (userLat && userLng) {
      const distKm = locationService.calculateDistance(parseFloat(userLat), parseFloat(userLng), latR, lngR);
      restaurant.distance = Math.round(distKm * 100) / 100;
      restaurant.distanceUnit = 'km';
    }
  }

  if (includeReviews === 'true') {
    const reviews = await Review.find({ restaurantId: id, isActive: true })
      .populate('userId', 'name avatar')
      .sort({ createdAt: -1 })
      .limit(10)
      .lean();
    restaurant.recentReviews = reviews;
  }

  await Restaurant.findByIdAndUpdate(id, { $inc: { viewCount: 1 } }).catch(() => {});

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Restaurant fetched', restaurant));
});

// GET /api/v1/restaurants/:id/availability?date=&time=&partySize=&durationMin=
exports.getAvailability = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { date, time, partySize = 2, durationMin = 90 } = req.query;

  if (!date || !time) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'date and time are required');
  }

  const available = await restaurantService.getAvailability({
    restaurantId: id,
    date,
    time,
    partySize: parseInt(partySize),
    durationMin: parseInt(durationMin)
  }); // { slots:[{timeISO, capacity}], policies, minSpend, notes }

  if (!available) throw new ApiError(StatusCodes.NOT_FOUND, 'Availability not available');

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Availability fetched', { ...available, generatedAt: toISO() }));
});

// POST /api/v1/restaurants/:id/book
// Body: { date, time, partySize, contact:{name,phone,email}, preferences?, specialRequests?, paymentMethod? }
exports.bookTable = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const payload = req.body || {};

  if (!payload.date || !payload.time || !payload.partySize || !payload.contact) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'date, time, partySize, contact are required');
  }

  const booking = await restaurantService.createReservation({
    restaurantId: id,
    ...payload,
    userId: req.user?.id
  }); // { bookingId, status, holdExpiresAtISO?, payment:{paymentUrl?,expiresAtISO?} }

  if (!booking) throw new ApiError(StatusCodes.INTERNAL_SERVER_ERROR, 'Failed to create reservation');

  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Reservation created', { ...booking, generatedAt: toISO() }));
});

// POST /api/v1/restaurants/:id/reviews
// Body: { rating, title, comment, photos[] }
exports.addReview = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { rating, title, comment, photos = [] } = req.body || {};
  if (!rating) throw new ApiError(StatusCodes.BAD_REQUEST, 'rating is required');

  // Optionally enforce completed reservation
  const completed = await Booking.findOne({ userId: req.user?.id, restaurantId: id, status: 'completed' }).lean();
  if (!completed) throw new ApiError(StatusCodes.FORBIDDEN, 'Review allowed only after completed visit');

  const review = await Review.create({
    userId: req.user?.id,
    restaurantId: id,
    type: 'restaurant',
    rating: parseFloat(rating),
    title,
    comment,
    photos
  });

  await restaurantService.updateRestaurantRating(id).catch(() => {});

  const populated = await Review.findById(review._id).populate('userId', 'name avatar').lean();
  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Review added', populated));
});

// GET /api/v1/restaurants/trending?city=&country=&limit=
exports.getTrending = asyncHandler(async (req, res) => {
  const { city, country, limit = 10 } = req.query;

  const cacheKey = `restaurants:trending:${city || 'all'}:${country || 'all'}:${limit}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Trending restaurants fetched (cache)', cached));
  }

  const match = { isActive: { $ne: false } };
  if (city) match.city = new RegExp(city, 'i');
  if (country) match.country = new RegExp(country, 'i');

  const rows = await Restaurant.aggregate([
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
        city: 1,
        country: 1,
        cuisines: 1,
        photos: { $slice: ['$photos', 3] },
        priceLevel: 1,
        'price.estimate': 1,
        'reviews.averageRating': 1,
        'reviews.totalReviews': 1,
        trendingScore: 1
      }
    }
  ]);

  const payload = { restaurants: rows, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 1800);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Trending restaurants fetched', payload));
});

// GET /api/v1/restaurants/facets?city=&country=
exports.getFacets = asyncHandler(async (req, res) => {
  const { city, country } = req.query;

  const match = { isActive: { $ne: false } };
  if (city) match.city = new RegExp(city, 'i');
  if (country) match.country = new RegExp(country, 'i');

  const [cuisines, priceLevels, dietary, features] = await Promise.all([
    Restaurant.aggregate([
      { $match: match },
      { $unwind: '$cuisines' },
      { $group: { _id: '$cuisines', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 100 },
      { $project: { _id: 0, cuisine: '$_id', count: 1 } }
    ]),
    Restaurant.aggregate([
      { $match: match },
      { $group: { _id: '$priceLevel', count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
      { $project: { _id: 0, priceLevel: '$_id', count: 1 } }
    ]),
    Restaurant.aggregate([
      { $match: match },
      { $unwind: '$dietaryOptions' },
      { $group: { _id: '$dietaryOptions', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 50 },
      { $project: { _id: 0, dietary: '$_id', count: 1 } }
    ]),
    Restaurant.aggregate([
      { $match: match },
      { $unwind: '$features' },
      { $group: { _id: '$features', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 50 },
      { $project: { _id: 0, feature: '$_id', count: 1 } }
    ])
  ]);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Facets fetched', {
      cuisines,
      priceLevels,
      dietary,
      features,
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/restaurants/:id/menu?category=&limit=
exports.getMenu = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { category, limit = 100 } = req.query;

  const menu = await restaurantService.getMenu({
    restaurantId: id,
    category: category || null,
    limit: clamp(parseInt(limit), 1, 500)
  }); // { categories:[], items:[{id,name,desc,price,currency,tags,dietary,photo}] }

  if (!menu) throw new ApiError(StatusCodes.NOT_FOUND, 'Menu not available');

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Menu fetched', { ...menu, generatedAt: toISO() }));
});

// GET /api/v1/restaurants/:id/photos?limit=&offset=
exports.getPhotos = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { limit = 20, offset = 0 } = req.query;

  const r = await Restaurant.findById(id).select('photos gallery').lean();
  if (!r) throw new ApiError(StatusCodes.NOT_FOUND, 'Restaurant not found');

  const reviewPhotos = await Review.find({
    restaurantId: id,
    photos: { $exists: true, $not: { $size: 0 } }
  })
    .populate('userId', 'name avatar')
    .select('photos userId createdAt')
    .sort({ createdAt: -1 })
    .limit(parseInt(limit))
    .skip(parseInt(offset))
    .lean();

  const data = {
    official: r.photos || [],
    gallery: r.gallery || [],
    userPhotos: reviewPhotos,
    total: (r.photos?.length || 0) + (r.gallery?.length || 0) + reviewPhotos.length
  };

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Photos fetched', data));
});

// GET /api/v1/restaurants/geojson?city=&country=&lat=&lng=&radius=&limit=
exports.getRestaurantsGeoJSON = asyncHandler(async (req, res) => {
  const filter = buildRestaurantFilter(req.query);
  const { limit = 2000 } = req.query;

  const rows = await Restaurant.find(filter)
    .limit(Math.min(parseInt(limit), 5000))
    .select('name city country tz location cuisines priceLevel reviews openNow')
    .lean();

  const features = rows
    .filter((r) => r?.location?.coordinates && Array.isArray(r.location.coordinates))
    .map((r) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: r.location.coordinates }, // [lng,lat] per RFC 7946
      properties: {
        id: r._id,
        type: 'restaurant',
        name: r.name,
        city: r.city || null,
        country: r.country || null,
        tz: r.tz || null,
        cuisines: r.cuisines || [],
        priceLevel: r.priceLevel || null,
        rating: r.reviews?.averageRating || null,
        openNow: !!r.openNow,
        geo: `geo:${r.location.coordinates},${r.location.coordinates}`
      }
    }));

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json'); // RFC 7946 media type
  return res.status(StatusCodes.OK).json(fc);
});
