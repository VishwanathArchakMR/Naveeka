// C:\flutterapp\myapp\backend\services\locationService.js

'use strict';

const mongoose = require('mongoose');
const LocationMaster = require('../models/LocationMaster');

function isObjectId(v) {
  return mongoose.Types.ObjectId.isValid(v);
}

function coerceInt(v, def) {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : def;
}

function coerceFloat(v, def) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : def;
}

function sanitizeRegex(s) {
  return s ? String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : '';
}

// ---------- Core getters ----------
async function getByIdOrSlug(idOrSlug) {
  if (!idOrSlug) return null;
  if (isObjectId(idOrSlug)) {
    return LocationMaster.findById(idOrSlug).lean();
  }
  return LocationMaster.findOne({ slug: idOrSlug }).lean();
}

function buildSort(sort) {
  switch (sort) {
    case 'name_asc':
      return { name: 1 };
    case 'popularity':
      return { popularity: -1, viewCount: -1, name: 1 };
    default:
      return { popularity: -1, viewCount: -1, name: 1 };
  }
}

function baseMatch(filters = {}) {
  const { type, countryIso2, regionSlug, countrySlug, tz } = filters;
  const match = { isActive: true };
  if (type) match.type = type; // country|region|city
  if (countryIso2) match.iso2 = countryIso2;
  if (countrySlug) match.countrySlug = countrySlug;
  if (regionSlug) match.regionSlug = regionSlug;
  if (tz) match.tz = tz;
  return match;
}

// ---------- Lists ----------
async function listCountries({ page = 1, limit = 50, sort = 'popularity' } = {}) {
  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 50), 200);
  const skip = (p - 1) * l;

  const match = baseMatch({ type: 'country' });

  const [items, total] = await Promise.all([
    LocationMaster.find(match)
      .select({ _id: 1, name: 1, slug: 1, iso2: 1, iso3: 1, currency: 1, tz: 1, centroid: 1, bbox: 1, popularity: 1, viewCount: 1 })
      .sort(buildSort(sort))
      .skip(skip)
      .limit(l)
      .lean(),
    LocationMaster.countDocuments(match)
  ]);

  return { items, page: p, limit: l, total, hasMore: skip + items.length < total };
}

async function listRegions({ countrySlug, page = 1, limit = 100, sort = 'popularity' } = {}) {
  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 100), 500);
  const skip = (p - 1) * l;

  const match = baseMatch({ type: 'region', countrySlug });

  const [items, total] = await Promise.all([
    LocationMaster.find(match)
      .select({ _id: 1, name: 1, slug: 1, countrySlug: 1, tz: 1, centroid: 1, bbox: 1, popularity: 1 })
      .sort(buildSort(sort))
      .skip(skip)
      .limit(l)
      .lean(),
    LocationMaster.countDocuments(match)
  ]);

  return { items, page: p, limit: l, total, hasMore: skip + items.length < total };
}

async function listCities({ countrySlug, regionSlug, page = 1, limit = 100, sort = 'popularity' } = {}) {
  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 100), 1000);
  const skip = (p - 1) * l;

  const match = baseMatch({ type: 'city', countrySlug, regionSlug });

  const [items, total] = await Promise.all([
    LocationMaster.find(match)
      .select({ _id: 1, name: 1, slug: 1, countrySlug: 1, regionSlug: 1, tz: 1, centroid: 1, popularity: 1 })
      .sort(buildSort(sort))
      .skip(skip)
      .limit(l)
      .lean(),
    LocationMaster.countDocuments(match)
  ]);

  return { items, page: p, limit: l, total, hasMore: skip + items.length < total };
}

// ---------- Suggestions ----------
async function suggest({ q, types = 'country,region,city', limit = 10, countrySlug, regionSlug }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const rx = q ? new RegExp(sanitizeRegex(q), 'i') : null;
  const typeSet = new Set(String(types).split(',').map((s) => s.trim()));

  const commonMatch = { isActive: true };
  if (countrySlug) commonMatch.countrySlug = countrySlug;
  if (regionSlug) commonMatch.regionSlug = regionSlug;

  const pick = { _id: 1, name: 1, slug: 1, type: 1, countrySlug: 1, regionSlug: 1, centroid: 1 };
  const res = {};

  if (typeSet.has('country')) {
    const m = { ...commonMatch, type: 'country' };
    if (rx) m.$or = [{ name: rx }, { iso2: rx }, { iso3: rx }, { aliases: rx }];
    res.countries = await LocationMaster.find(m).select(pick).limit(l).lean();
  }

  if (typeSet.has('region')) {
    const m = { ...commonMatch, type: 'region' };
    if (rx) m.$or = [{ name: rx }, { regionSlug: rx }, { aliases: rx }];
    res.regions = await LocationMaster.find(m).select(pick).limit(l).lean();
  }

  if (typeSet.has('city')) {
    const m = { ...commonMatch, type: 'city' };
    if (rx) m.$or = [{ name: rx }, { aliases: rx }];
    res.cities = await LocationMaster.find(m).select(pick).limit(l).lean();
  }

  return res;
}

// ---------- Nearby cities (by centroid) ----------
async function nearbyCities({ lat, lng, radiusKm = 50, limit = 100, countrySlug, regionSlug }) {
  const l = Math.min(coerceInt(limit, 100), 500);

  const match = { isActive: true, type: 'city' };
  if (countrySlug) match.countrySlug = countrySlug;
  if (regionSlug) match.regionSlug = regionSlug;

  const pipeline = [
    {
      $geoNear: {
        near: { type: 'Point', coordinates: [coerceFloat(lng, 0), coerceFloat(lat, 0)] },
        distanceField: 'distanceMeters',
        spherical: true,
        maxDistance: coerceFloat(radiusKm, 50) * 1000,
        key: 'centroid',
        query: match
      }
    },
    { $limit: l }
  ];

  const items = await LocationMaster.aggregate(pipeline);
  return items;
}

// ---------- BBox (viewport) ----------
async function getByBBox({ type, minLng, minLat, maxLng, maxLat, limit = 1000, countrySlug, regionSlug }) {
  const l = Math.min(coerceInt(limit, 1000), 5000);
  const polygon = {
    type: 'Polygon',
    coordinates: [[
      [coerceFloat(minLng, 0), coerceFloat(minLat, 0)],
      [coerceFloat(maxLng, 0), coerceFloat(minLat, 0)],
      [coerceFloat(maxLng, 0), coerceFloat(maxLat, 0)],
      [coerceFloat(minLng, 0), coerceFloat(maxLat, 0)],
      [coerceFloat(minLng, 0), coerceFloat(minLat, 0)]
    ]]
  };

  const match = { isActive: true };
  if (type) match.type = type;
  if (countrySlug) match.countrySlug = countrySlug;
  if (regionSlug) match.regionSlug = regionSlug;

  // For cities, test centroid within bbox; for regions/countries, test their bbox polygon intersects viewport
  const cityItemsPromise = LocationMaster.find({ ...match, type: 'city', centroid: { $geoWithin: { $geometry: polygon } } })
    .select({ _id: 1, name: 1, slug: 1, centroid: 1, type: 1, countrySlug: 1, regionSlug: 1, popularity: 1 })
    .limit(l)
    .lean();

  const regionItemsPromise = LocationMaster.find({ ...match, type: 'region', bbox: { $geoWithin: { $geometry: polygon } } })
    .select({ _id: 1, name: 1, slug: 1, bbox: 1, type: 1, countrySlug: 1, popularity: 1 })
    .limit(l)
    .lean();

  const countryItemsPromise = LocationMaster.find({ ...match, type: 'country', bbox: { $geoWithin: { $geometry: polygon } } })
    .select({ _id: 1, name: 1, slug: 1, bbox: 1, type: 1, iso2: 1, iso3: 1, popularity: 1 })
    .limit(l)
    .lean();

  const [cities, regions, countries] = await Promise.all([cityItemsPromise, regionItemsPromise, countryItemsPromise]);

  // If type specified, return only that type list; else combine
  if (type === 'city') return cities;
  if (type === 'region') return regions;
  if (type === 'country') return countries;
  return [...countries, ...regions, ...cities];
}

// ---------- GeoJSON outputs ----------
async function getGeoJSON({ type = 'city', countrySlug, regionSlug, limit = 5000 }) {
  const l = Math.min(coerceInt(limit, 5000), 10000);
  const match = baseMatch({ type, countrySlug, regionSlug });

  const items = await LocationMaster.find(match)
    .select({ _id: 1, name: 1, slug: 1, type: 1, iso2: 1, iso3: 1, tz: 1, centroid: 1, bbox: 1, popularity: 1 })
    .limit(l)
    .lean();

  // Cities -> Point; Regions/Countries -> Polygon (bbox) + centroid Point feature
  const features = [];
  for (const it of items) {
    if (type === 'city' && it.centroid?.type === 'Point') {
      features.push({
        type: 'Feature',
        geometry: it.centroid,
        properties: {
          id: String(it._id),
          type: it.type,
          name: it.name,
          slug: it.slug,
          tz: it.tz,
          countrySlug: it.countrySlug,
          regionSlug: it.regionSlug,
          popularity: it.popularity ?? 0
        }
      });
    } else if ((type === 'region' || type === 'country') && it.bbox?.type === 'Polygon') {
      features.push({
        type: 'Feature',
        geometry: it.bbox,
        properties: {
          id: String(it._id),
          type: it.type,
          name: it.name,
          slug: it.slug,
          iso2: it.iso2 || null,
          iso3: it.iso3 || null,
          tz: it.tz,
          popularity: it.popularity ?? 0
        }
      });

      if (it.centroid?.type === 'Point') {
        features.push({
          type: 'Feature',
          geometry: it.centroid,
          properties: {
            id: String(it._id) + ':centroid',
            type: it.type + '_centroid',
            name: it.name,
            slug: it.slug
          }
        });
      }
    }
  }

  return { type: 'FeatureCollection', features };
}

// ---------- Facets & Trending ----------
async function getFacets() {
  const [countries, regions, cities] = await Promise.all([
    LocationMaster.aggregate([
      { $match: { isActive: true, type: 'country' } },
      { $group: { _id: '$iso2', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]),
    LocationMaster.aggregate([
      { $match: { isActive: true, type: 'region' } },
      { $group: { _id: '$countrySlug', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]),
    LocationMaster.aggregate([
      { $match: { isActive: true, type: 'city' } },
      { $group: { _id: '$countrySlug', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ])
  ]);

  return {
    countriesByIso2: countries.map((r) => ({ iso2: r._id, count: r.count })),
    regionsPerCountry: regions.map((r) => ({ countrySlug: r._id, count: r.count })),
    citiesPerCountry: cities.map((r) => ({ countrySlug: r._id, count: r.count }))
  };
}

async function getTrending({ type = 'city', limit = 10, countrySlug, regionSlug } = {}) {
  const l = Math.min(coerceInt(limit, 10), 50);
  const match = baseMatch({ type, countrySlug, regionSlug });

  const items = await LocationMaster.find(match)
    .sort({ popularity: -1, viewCount: -1 })
    .limit(l)
    .lean();

  return items;
}

module.exports = {
  getByIdOrSlug,
  listCountries,
  listRegions,
  listCities,
  suggest,
  nearbyCities,
  getByBBox,
  getGeoJSON,
  getFacets,
  getTrending
};
