// C:\flutterapp\myapp\backend\controllers\atlasController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Place = require('../models/Place');
const Hotel = require('../models/Hotel');
const Restaurant = require('../models/Restaurant');
const Activity = require('../models/Activity');
const Airport = require('../models/Airport');
const TrainStation = require('../models/TrainStation');
const BusStop = require('../models/BusStop');
const Trail = require('../models/Trail');

// Services
const cacheService = require('../services/cacheService'); // optional Redis cache
const locationService = require('../services/locationService'); // distance helpers
const mapService = require('../services/mapService'); // optional: cluster, bbox helpers

// Utils
const toISO = (d = new Date()) => d.toISOString();

// Parse helpers
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const isFiniteNumber = (n) => typeof n === 'number' && Number.isFinite(n);

// Build $geoWithin polygon from bbox [minLng,minLat,maxLng,maxLat]
function bboxToPolygon(bboxArr) {
  const [minLng, minLat, maxLng, maxLat] = bboxArr.map(Number);
  return {
    type: 'Polygon',
    coordinates: [[
      [minLng, minLat],
      [maxLng, minLat],
      [maxLng, maxLat],
      [minLng, maxLat],
      [minLng, minLat]
    ]]
  };
}

// Map DB document to GeoJSON Feature with consistent props
function toFeature(doc, kind) {
  // Expect doc.location.coordinates as [lng, lat]
  const coords = doc?.location?.coordinates;
  if (!coords || !Array.isArray(coords) || coords.length < 2) return null;

  const [lng, lat] = coords;

  const base = {
    id: doc._id,
    type: kind,
    name: doc.name || doc.title || kind,
    city: doc.city || doc.address?.city || null,
    state: doc.state || doc.address?.state || null,
    country: doc.country || doc.address?.country || null,
    tz: doc.tz || doc.timezone || null,
    geo: `geo:${lat},${lng}`,
    rating: doc.rating?.score || doc.reviews?.averageRating || null,
    reviews: doc.rating?.reviews || doc.reviews?.totalReviews || null,
    tags: doc.tags || [],
    category: doc.category || doc.categories || null,
  };

  // Type-specific enrichments
  if (kind === 'airport') {
    base.iata = doc.iata || null;
    base.icao = doc.icao || null;
  }
  if (kind === 'train_station') {
    base.station_code = doc.station_code || doc.code || null;
  }
  if (kind === 'bus_stop') {
    base.stop_code = doc.stop_code || doc.code || null;
  }
  if (kind === 'hotel') {
    base.stars = doc.stars || null;
    base.price = doc.price || doc.pricing?.basePrice || null;
    base.currency = doc.currency || doc.pricing?.currency || null;
  }
  if (kind === 'restaurant') {
    base.cuisines = doc.cuisines || [];
    base.priceLevel = doc.price?.level || null;
    base.currency = doc.price?.currency || null;
  }
  if (kind === 'activity') {
    base.duration = doc.duration || null;
    base.difficulty = doc.difficulty || null;
    base.price = doc.pricing?.basePrice || null;
    base.currency = doc.pricing?.currency || null;
  }
  if (kind === 'place') {
    base.features = doc.features || [];
  }
  if (kind === 'trail') {
    base.length_km = doc.length_km || null;
    base.difficulty = doc.difficulty || null;
  }

  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: base
  };
}

// Build per-type Mongoose filter based on request-level filter hints
function buildCommonFilters({ q, city, country, tags, category }) {
  const filter = { isActive: { $ne: false } };

  if (q) {
    filter.$or = [
      { name: new RegExp(q, 'i') },
      { title: new RegExp(q, 'i') },
      { 'address.city': new RegExp(q, 'i') },
      { city: new RegExp(q, 'i') },
      { 'address.country': new RegExp(q, 'i') },
      { country: new RegExp(q, 'i') },
    ];
  }
  if (city) {
    filter.$or = (filter.$or || []).concat([{ 'address.city': new RegExp(city, 'i') }, { city: new RegExp(city, 'i') }]);
  }
  if (country) {
    filter.$or = (filter.$or || []).concat([{ 'address.country': new RegExp(country, 'i') }, { country: new RegExp(country, 'i') }]);
  }
  if (tags && tags.length) {
    filter.tags = { $in: tags };
  }
  if (category) {
    // category may be array or string
    const cats = Array.isArray(category) ? category : parseCSV(category);
    if (cats.length) {
      filter.$or = (filter.$or || []).concat([{ category: { $in: cats } }, { categories: { $in: cats } }]);
    }
  }

  return filter;
}

// Optionally apply geospatial constraints
function applyGeoFilters(baseFilter, { lat, lng, radiusKm, bbox }) {
  const filter = { ...baseFilter };

  if (bbox && bbox.length === 4) {
    filter.location = {
      $geoWithin: {
        $geometry: bboxToPolygon(bbox)
      }
    };
  } else if (isFiniteNumber(lat) && isFiniteNumber(lng) && isFiniteNumber(radiusKm) && radiusKm > 0) {
    filter.location = {
      $near: {
        $geometry: { type: 'Point', coordinates: [lng, lat] },
        $maxDistance: radiusKm * 1000
      }
    };
  }

  return filter;
}

// GET /api/v1/atlas/locations
// Returns RFC 7946 FeatureCollection with all requested types
exports.getLocations = asyncHandler(async (req, res) => {
  const {
    types, // csv: airports,train_stations,bus_stops,places,hotels,restaurants,activities,trails
    q,
    city,
    country,
    tags, // csv
    category, // csv
    lat,
    lng,
    radius, // km
    bbox, // csv: minLng,minLat,maxLng,maxLat
    limit = 200, // overall cap
    perType = 100 // cap per type
  } = req.query;

  const selectedTypes = parseCSV(types).length
    ? parseCSV(types)
    : ['airports', 'train_stations', 'bus_stops', 'places', 'hotels', 'restaurants', 'activities', 'trails'];

  const tagArr = parseCSV(tags);
  const bboxArr = parseCSV(bbox).map(Number);
  const latNum = parseNum(lat);
  const lngNum = parseNum(lng);
  const radiusKm = parseNum(radius);

  const common = buildCommonFilters({ q, city, country, tags: tagArr, category });
  const geoOpts = { lat: latNum, lng: lngNum, radiusKm, bbox: bboxArr.length === 4 ? bboxArr : null };
  const perTypeLimit = Math.min(parseInt(perType), Math.max(25, Math.floor(parseInt(limit) / Math.max(1, selectedTypes.length))));

  const cacheKey = `atlas:locations:${JSON.stringify({ selectedTypes, q, city, country, tagArr, category, latNum, lngNum, radiusKm, bboxArr, perTypeLimit })}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    res.setHeader('Content-Type', 'application/geo+json');
    return res.status(StatusCodes.OK).json(cached);
  }

  const jobs = [];

  if (selectedTypes.includes('airports')) {
    jobs.push(
      Airport.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name iata icao city country tz location rating reviews tags')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'airport')).filter(Boolean))
    );
  }
  if (selectedTypes.includes('train_stations')) {
    jobs.push(
      TrainStation.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name station_code city country tz location rating reviews tags')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'train_station')).filter(Boolean))
    );
  }
  if (selectedTypes.includes('bus_stops')) {
    jobs.push(
      BusStop.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name stop_code city country tz location rating reviews tags')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'bus_stop')).filter(Boolean))
    );
  }
  if (selectedTypes.includes('places')) {
    jobs.push(
      Place.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name city country address location rating reviews tags category categories features')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'place')).filter(Boolean))
    );
  }
  if (selectedTypes.includes('hotels')) {
    jobs.push(
      Hotel.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name city country address location rating reviews tags stars pricing currency')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'hotel')).filter(Boolean))
    );
  }
  if (selectedTypes.includes('restaurants')) {
    jobs.push(
      Restaurant.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name city country address location rating reviews tags cuisines price')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'restaurant')).filter(Boolean))
    );
  }
  if (selectedTypes.includes('activities')) {
    jobs.push(
      Activity.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name city country address location rating reviews tags duration difficulty pricing')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'activity')).filter(Boolean))
    );
  }
  if (selectedTypes.includes('trails')) {
    jobs.push(
      Trail.find(applyGeoFilters(common, geoOpts))
        .limit(perTypeLimit)
        .select('name city country location rating reviews tags length_km difficulty')
        .lean()
        .then((rows) => rows.map((r) => toFeature(r, 'trail')).filter(Boolean))
    );
  }

  const all = (await Promise.all(jobs)).flat().slice(0, Math.min(parseInt(limit), 5000));

  const fc = {
    type: 'FeatureCollection',
    features: all,
    generatedAt: toISO()
  };

  res.setHeader('Content-Type', 'application/geo+json');
  await cacheService?.set?.(cacheKey, fc, 300); // cache 5 minutes
  return res.status(StatusCodes.OK).json(fc);
});

// GET /api/v1/atlas/nearby?lat=&lng=&radius=&types=...
// Convenience wrapper to fetch around a point across types
exports.getNearby = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 25, types } = req.query;

  if (!lat || !lng) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');
  }

  // Reuse getLocations logic by shaping the query
  req.query = {
    ...req.query,
    lat,
    lng,
    radius,
    bbox: undefined
  };
  return exports.getLocations(req, res);
});

// GET /api/v1/atlas/stats
// Returns counts per type for current filter context
exports.getStats = asyncHandler(async (req, res) => {
  const { q, city, country, tags, category } = req.query;
  const tagArr = parseCSV(tags);
  const common = buildCommonFilters({ q, city, country, tags: tagArr, category });

  const [airports, trainStations, busStops, places, hotels, restaurants, activities, trails] = await Promise.all([
    Airport.countDocuments(common),
    TrainStation.countDocuments(common),
    BusStop.countDocuments(common),
    Place.countDocuments(common),
    Hotel.countDocuments(common),
    Restaurant.countDocuments(common),
    Activity.countDocuments(common),
    Trail.countDocuments(common)
  ]);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Atlas stats fetched', {
      counts: {
        airports,
        train_stations: trainStations,
        bus_stops: busStops,
        places,
        hotels,
        restaurants,
        activities,
        trails
      },
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/atlas/clusters?bbox=&zoom=&types=...
// Optional clustering endpoint if mapService supports clustering
exports.getClusters = asyncHandler(async (req, res) => {
  const { bbox, zoom = 6, types } = req.query;
  const bboxArr = parseCSV(bbox).map(Number);

  if (!bboxArr.length || bboxArr.length !== 4) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'bbox is required as minLng,minLat,maxLng,maxLat');
  }

  // Get base features within bbox
  const fakeReq = { ...req, query: { ...req.query, bbox, lat: undefined, lng: undefined, radius: undefined } };
  const fakeRes = {
    setHeader: () => {},
    status: () => ({ json: (d) => d })
  };
  const fc = await exports.getLocations(fakeReq, fakeRes);
  const features = fc?.features || [];

  // Cluster via mapService or return raw if not available
  let clusters = features;
  if (mapService?.clusterFeatures) {
    clusters = mapService.clusterFeatures(features, {
      bbox: bboxArr,
      zoom: Number(zoom)
    });
  }

  const collection = { type: 'FeatureCollection', features: clusters, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(collection);
});
