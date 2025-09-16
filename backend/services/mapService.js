// C:\flutterapp\myapp\backend\services\mapService.js

'use strict';

const mongoose = require('mongoose');

// Models used for map layers (adjust paths if different)
const Airport = require('../models/Airport');
const Hotel = require('../models/Hotel');
const Restaurant = require('../models/Restaurant');
const Activity = require('../models/Activity');
const BusStop = require('../models/BusStop');
const TrainStation = require('../models/TrainStation');
const LocationMaster = require('../models/LocationMaster');
const Trail = require('../models/Trail');
const Bus = require('../models/Bus');
const Train = require('../models/Train');

// ---------------- Helpers ----------------

function coerceFloat(v, def) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : def;
}

function bboxPolygon({ minLng, minLat, maxLng, maxLat }) {
  // RFC 7946 uses [longitude, latitude] with rings closed (first == last)
  const a = coerceFloat(minLng, 0);
  const b = coerceFloat(minLat, 0);
  const c = coerceFloat(maxLng, 0);
  const d = coerceFloat(maxLat, 0);
  return {
    type: 'Polygon',
    coordinates: [[
      [a, b],
      [c, b],
      [c, d],
      [a, d],
      [a, b]
    ]]
  };
}

function toFeaturePoint(coords, properties = {}) {
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: coords },
    properties
  };
}

function wrapGeometryAsCollection(geometry, properties = {}) {
  if (!geometry) return { type: 'FeatureCollection', features: [] };
  if (geometry.type === 'FeatureCollection') return geometry;
  return {
    type: 'FeatureCollection',
    features: [{ type: 'Feature', geometry, properties }]
  };
}

// ---------------- Point layers via bbox ----------------

async function fetchPointLayer({ Model, locationKey = 'location', select, bbox, limit = 200, extraMatch = {}, propMapper }) {
  const match = { isActive: true, ...extraMatch };
  if (bbox) {
    match[locationKey] = { $geoWithin: { $geometry: bboxPolygon(bbox) } };
  }
  const items = await Model.find(match)
    .select(select)
    .limit(Math.min(limit, 2000))
    .lean();

  const features = [];
  for (const it of items) {
    const loc = it?.[locationKey];
    if (loc?.type === 'Point' && Array.isArray(loc.coordinates)) {
      const props = propMapper ? propMapper(it) : { id: String(it._id) };
      features.push(toFeaturePoint(loc.coordinates, props));
    }
  }
  return features;
}

// ---------------- Line layers (no bbox filter by default) ----------------

async function fetchLineLayer({ Model, geomKey, select, limit = 200, extraMatch = {}, propMapper }) {
  const match = { isActive: true, ...extraMatch };
  const items = await Model.find(match)
    .select(select)
    .limit(Math.min(limit, 2000))
    .lean();

  const features = [];
  for (const it of items) {
    const geom = it?.[geomKey];
    if (geom?.type === 'LineString' || geom?.type === 'MultiLineString') {
      const props = propMapper ? propMapper(it) : { id: String(it._id) };
      features.push({ type: 'Feature', geometry: geom, properties: props });
    } else if (geom?.type === 'FeatureCollection') {
      for (const f of geom.features || []) {
        const props = propMapper ? propMapper(it) : { id: String(it._id) };
        features.push({ type: 'Feature', geometry: f.geometry, properties: props });
      }
    }
  }
  return features;
}

// ---------------- Public API ----------------

/**
 * getLayersGeoJSON
 * Combine multiple map layers into a single FeatureCollection.
 * params:
 *   - layers: array of layer ids to include (defaults listed below)
 *   - bbox: { minLng, minLat, maxLng, maxLat } for viewport filtering (applies to point layers)
 *   - perLayerLimit: max docs per layer
 *   - filters: optional per-layer match fragments by key
 */
async function getLayersGeoJSON({
  layers = [
    'airports',
    'hotels',
    'restaurants',
    'activities',
    'busStops',
    'trainStations',
    'cities',
    'trails',
    'buses',
    'trains'
  ],
  bbox = null,
  perLayerLimit = 500,
  filters = {}
} = {}) {
  const features = [];

  // Airports (Point)
  if (layers.includes('airports')) {
    features.push(
      ...await fetchPointLayer({
        Model: Airport,
        locationKey: 'location',
        select: { name: 1, iata: 1, city: 1, country: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.airports || {},
        propMapper: (a) => ({
          id: String(a._id),
          layer: 'airport',
          name: a.name,
          iata: a.iata,
          city: a.city,
          country: a.country
        })
      })
    );
  }

  // Hotels (Point)
  if (layers.includes('hotels')) {
    features.push(
      ...await fetchPointLayer({
        Model: Hotel,
        locationKey: 'location',
        select: { name: 1, slug: 1, stars: 1, price: 1, reviews: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.hotels || {},
        propMapper: (h) => ({
          id: String(h._id),
          layer: 'hotel',
          name: h.name,
          slug: h.slug,
          stars: h.stars ?? null,
          price: h.price || null,
          rating: h.reviews?.averageRating ?? null
        })
      })
    );
  }

  // Restaurants (Point)
  if (layers.includes('restaurants')) {
    features.push(
      ...await fetchPointLayer({
        Model: Restaurant,
        locationKey: 'location',
        select: { name: 1, slug: 1, cuisines: 1, priceBucket: 1, reviews: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.restaurants || {},
        propMapper: (r) => ({
          id: String(r._id),
          layer: 'restaurant',
          name: r.name,
          slug: r.slug,
          cuisines: r.cuisines || [],
          priceBucket: r.priceBucket || null,
          rating: r.reviews?.averageRating ?? null
        })
      })
    );
  }

  // Activities (Point)
  if (layers.includes('activities')) {
    features.push(
      ...await fetchPointLayer({
        Model: Activity,
        locationKey: 'location',
        select: { name: 1, slug: 1, type: 1, tags: 1, price: 1, reviews: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.activities || {},
        propMapper: (a) => ({
          id: String(a._id),
          layer: 'activity',
          name: a.name,
          slug: a.slug,
          type: a.type,
          tags: a.tags || [],
          price: a.price || null,
          rating: a.reviews?.averageRating ?? null
        })
      })
    );
  }

  // Bus stops (Point)
  if (layers.includes('busStops')) {
    features.push(
      ...await fetchPointLayer({
        Model: BusStop,
        locationKey: 'location',
        select: { name: 1, stop_code: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.busStops || {},
        propMapper: (s) => ({
          id: String(s._id),
          layer: 'bus_stop',
          name: s.name,
          code: s.stop_code
        })
      })
    );
  }

  // Train stations (Point)
  if (layers.includes('trainStations')) {
    features.push(
      ...await fetchPointLayer({
        Model: TrainStation,
        locationKey: 'location',
        select: { name: 1, station_code: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.trainStations || {},
        propMapper: (s) => ({
          id: String(s._id),
          layer: 'train_station',
          name: s.name,
          code: s.station_code
        })
      })
    );
  }

  // Cities (Point via centroid in LocationMaster)
  if (layers.includes('cities')) {
    features.push(
      ...await fetchPointLayer({
        Model: LocationMaster,
        locationKey: 'centroid',
        select: { name: 1, slug: 1, type: 1, countrySlug: 1, regionSlug: 1, centroid: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: { ...(filters.cities || {}), type: 'city' },
        propMapper: (c) => ({
          id: String(c._id),
          layer: 'city',
          name: c.name,
          slug: c.slug,
          countrySlug: c.countrySlug,
          regionSlug: c.regionSlug
        })
      })
    );
  }

  // Trails (LineString or FeatureCollection)
  if (layers.includes('trails')) {
    features.push(
      ...await fetchLineLayer({
        Model: Trail,
        geomKey: 'routeGeoJSON',
        select: { name: 1, slug: 1, difficulty: 1, lengthKm: 1, routeGeoJSON: 1 },
        limit: perLayerLimit,
        extraMatch: filters.trails || {},
        propMapper: (t) => ({
          id: String(t._id),
          layer: 'trail',
          name: t.name,
          slug: t.slug,
          difficulty: t.difficulty || null,
          lengthKm: t.lengthKm ?? null
        })
      })
    );
  }

  // Buses (LineString)
  if (layers.includes('buses')) {
    features.push(
      ...await fetchLineLayer({
        Model: Bus,
        geomKey: 'coordinatesGeoJSON',
        select: { number: 1, operator: 1, coordinatesGeoJSON: 1 },
        limit: perLayerLimit,
        extraMatch: filters.buses || {},
        propMapper: (b) => ({
          id: String(b._id),
          layer: 'bus_route',
          number: b.number,
          operator: b.operator
        })
      })
    );
  }

  // Trains (LineString)
  if (layers.includes('trains')) {
    features.push(
      ...await fetchLineLayer({
        Model: Train,
        geomKey: 'coordinatesGeoJSON',
        select: { number: 1, operator: 1, coordinatesGeoJSON: 1 },
        limit: perLayerLimit,
        extraMatch: filters.trains || {},
        propMapper: (t) => ({
          id: String(t._id),
          layer: 'train_route',
          number: t.number,
          operator: t.operator
        })
      })
    );
  }

  return { type: 'FeatureCollection', features };
}

/**
 * getBBoxPolygon
 * Utility exposed for controllers needing a consistent bbox polygon.
 */
function getBBoxPolygon({ minLng, minLat, maxLng, maxLat }) {
  return bboxPolygon({ minLng, minLat, maxLng, maxLat });
}

module.exports = {
  getLayersGeoJSON,
  getBBoxPolygon,
  wrapGeometryAsCollection
};
// C:\flutterapp\myapp\backend\services\mapService.js

'use strict';

const mongoose = require('mongoose');

// Models used for map layers (adjust paths if different)
const Airport = require('../models/Airport');
const Hotel = require('../models/Hotel');
const Restaurant = require('../models/Restaurant');
const Activity = require('../models/Activity');
const BusStop = require('../models/BusStop');
const TrainStation = require('../models/TrainStation');
const LocationMaster = require('../models/LocationMaster');
const Trail = require('../models/Trail');
const Bus = require('../models/Bus');
const Train = require('../models/Train');

// ---------------- Helpers ----------------

function coerceFloat(v, def) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : def;
}

function bboxPolygon({ minLng, minLat, maxLng, maxLat }) {
  // RFC 7946 uses [longitude, latitude] with rings closed (first == last)
  const a = coerceFloat(minLng, 0);
  const b = coerceFloat(minLat, 0);
  const c = coerceFloat(maxLng, 0);
  const d = coerceFloat(maxLat, 0);
  return {
    type: 'Polygon',
    coordinates: [[
      [a, b],
      [c, b],
      [c, d],
      [a, d],
      [a, b]
    ]]
  };
}

function toFeaturePoint(coords, properties = {}) {
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: coords },
    properties
  };
}

function wrapGeometryAsCollection(geometry, properties = {}) {
  if (!geometry) return { type: 'FeatureCollection', features: [] };
  if (geometry.type === 'FeatureCollection') return geometry;
  return {
    type: 'FeatureCollection',
    features: [{ type: 'Feature', geometry, properties }]
  };
}

// ---------------- Point layers via bbox ----------------

async function fetchPointLayer({ Model, locationKey = 'location', select, bbox, limit = 200, extraMatch = {}, propMapper }) {
  const match = { isActive: true, ...extraMatch };
  if (bbox) {
    match[locationKey] = { $geoWithin: { $geometry: bboxPolygon(bbox) } };
  }
  const items = await Model.find(match)
    .select(select)
    .limit(Math.min(limit, 2000))
    .lean();

  const features = [];
  for (const it of items) {
    const loc = it?.[locationKey];
    if (loc?.type === 'Point' && Array.isArray(loc.coordinates)) {
      const props = propMapper ? propMapper(it) : { id: String(it._id) };
      features.push(toFeaturePoint(loc.coordinates, props));
    }
  }
  return features;
}

// ---------------- Line layers (no bbox filter by default) ----------------

async function fetchLineLayer({ Model, geomKey, select, limit = 200, extraMatch = {}, propMapper }) {
  const match = { isActive: true, ...extraMatch };
  const items = await Model.find(match)
    .select(select)
    .limit(Math.min(limit, 2000))
    .lean();

  const features = [];
  for (const it of items) {
    const geom = it?.[geomKey];
    if (geom?.type === 'LineString' || geom?.type === 'MultiLineString') {
      const props = propMapper ? propMapper(it) : { id: String(it._id) };
      features.push({ type: 'Feature', geometry: geom, properties: props });
    } else if (geom?.type === 'FeatureCollection') {
      for (const f of geom.features || []) {
        const props = propMapper ? propMapper(it) : { id: String(it._id) };
        features.push({ type: 'Feature', geometry: f.geometry, properties: props });
      }
    }
  }
  return features;
}

// ---------------- Public API ----------------

/**
 * getLayersGeoJSON
 * Combine multiple map layers into a single FeatureCollection.
 * params:
 *   - layers: array of layer ids to include (defaults listed below)
 *   - bbox: { minLng, minLat, maxLng, maxLat } for viewport filtering (applies to point layers)
 *   - perLayerLimit: max docs per layer
 *   - filters: optional per-layer match fragments by key
 */
async function getLayersGeoJSON({
  layers = [
    'airports',
    'hotels',
    'restaurants',
    'activities',
    'busStops',
    'trainStations',
    'cities',
    'trails',
    'buses',
    'trains'
  ],
  bbox = null,
  perLayerLimit = 500,
  filters = {}
} = {}) {
  const features = [];

  // Airports (Point)
  if (layers.includes('airports')) {
    features.push(
      ...await fetchPointLayer({
        Model: Airport,
        locationKey: 'location',
        select: { name: 1, iata: 1, city: 1, country: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.airports || {},
        propMapper: (a) => ({
          id: String(a._id),
          layer: 'airport',
          name: a.name,
          iata: a.iata,
          city: a.city,
          country: a.country
        })
      })
    );
  }

  // Hotels (Point)
  if (layers.includes('hotels')) {
    features.push(
      ...await fetchPointLayer({
        Model: Hotel,
        locationKey: 'location',
        select: { name: 1, slug: 1, stars: 1, price: 1, reviews: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.hotels || {},
        propMapper: (h) => ({
          id: String(h._id),
          layer: 'hotel',
          name: h.name,
          slug: h.slug,
          stars: h.stars ?? null,
          price: h.price || null,
          rating: h.reviews?.averageRating ?? null
        })
      })
    );
  }

  // Restaurants (Point)
  if (layers.includes('restaurants')) {
    features.push(
      ...await fetchPointLayer({
        Model: Restaurant,
        locationKey: 'location',
        select: { name: 1, slug: 1, cuisines: 1, priceBucket: 1, reviews: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.restaurants || {},
        propMapper: (r) => ({
          id: String(r._id),
          layer: 'restaurant',
          name: r.name,
          slug: r.slug,
          cuisines: r.cuisines || [],
          priceBucket: r.priceBucket || null,
          rating: r.reviews?.averageRating ?? null
        })
      })
    );
  }

  // Activities (Point)
  if (layers.includes('activities')) {
    features.push(
      ...await fetchPointLayer({
        Model: Activity,
        locationKey: 'location',
        select: { name: 1, slug: 1, type: 1, tags: 1, price: 1, reviews: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.activities || {},
        propMapper: (a) => ({
          id: String(a._id),
          layer: 'activity',
          name: a.name,
          slug: a.slug,
          type: a.type,
          tags: a.tags || [],
          price: a.price || null,
          rating: a.reviews?.averageRating ?? null
        })
      })
    );
  }

  // Bus stops (Point)
  if (layers.includes('busStops')) {
    features.push(
      ...await fetchPointLayer({
        Model: BusStop,
        locationKey: 'location',
        select: { name: 1, stop_code: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.busStops || {},
        propMapper: (s) => ({
          id: String(s._id),
          layer: 'bus_stop',
          name: s.name,
          code: s.stop_code
        })
      })
    );
  }

  // Train stations (Point)
  if (layers.includes('trainStations')) {
    features.push(
      ...await fetchPointLayer({
        Model: TrainStation,
        locationKey: 'location',
        select: { name: 1, station_code: 1, location: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: filters.trainStations || {},
        propMapper: (s) => ({
          id: String(s._id),
          layer: 'train_station',
          name: s.name,
          code: s.station_code
        })
      })
    );
  }

  // Cities (Point via centroid in LocationMaster)
  if (layers.includes('cities')) {
    features.push(
      ...await fetchPointLayer({
        Model: LocationMaster,
        locationKey: 'centroid',
        select: { name: 1, slug: 1, type: 1, countrySlug: 1, regionSlug: 1, centroid: 1 },
        bbox,
        limit: perLayerLimit,
        extraMatch: { ...(filters.cities || {}), type: 'city' },
        propMapper: (c) => ({
          id: String(c._id),
          layer: 'city',
          name: c.name,
          slug: c.slug,
          countrySlug: c.countrySlug,
          regionSlug: c.regionSlug
        })
      })
    );
  }

  // Trails (LineString or FeatureCollection)
  if (layers.includes('trails')) {
    features.push(
      ...await fetchLineLayer({
        Model: Trail,
        geomKey: 'routeGeoJSON',
        select: { name: 1, slug: 1, difficulty: 1, lengthKm: 1, routeGeoJSON: 1 },
        limit: perLayerLimit,
        extraMatch: filters.trails || {},
        propMapper: (t) => ({
          id: String(t._id),
          layer: 'trail',
          name: t.name,
          slug: t.slug,
          difficulty: t.difficulty || null,
          lengthKm: t.lengthKm ?? null
        })
      })
    );
  }

  // Buses (LineString)
  if (layers.includes('buses')) {
    features.push(
      ...await fetchLineLayer({
        Model: Bus,
        geomKey: 'coordinatesGeoJSON',
        select: { number: 1, operator: 1, coordinatesGeoJSON: 1 },
        limit: perLayerLimit,
        extraMatch: filters.buses || {},
        propMapper: (b) => ({
          id: String(b._id),
          layer: 'bus_route',
          number: b.number,
          operator: b.operator
        })
      })
    );
  }

  // Trains (LineString)
  if (layers.includes('trains')) {
    features.push(
      ...await fetchLineLayer({
        Model: Train,
        geomKey: 'coordinatesGeoJSON',
        select: { number: 1, operator: 1, coordinatesGeoJSON: 1 },
        limit: perLayerLimit,
        extraMatch: filters.trains || {},
        propMapper: (t) => ({
          id: String(t._id),
          layer: 'train_route',
          number: t.number,
          operator: t.operator
        })
      })
    );
  }

  return { type: 'FeatureCollection', features };
}

/**
 * getBBoxPolygon
 * Utility exposed for controllers needing a consistent bbox polygon.
 */
function getBBoxPolygon({ minLng, minLat, maxLng, maxLat }) {
  return bboxPolygon({ minLng, minLat, maxLng, maxLat });
}

module.exports = {
  getLayersGeoJSON,
  getBBoxPolygon,
  wrapGeometryAsCollection
};
