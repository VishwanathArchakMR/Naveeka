// C:\flutterapp\myapp\backend\services\trainService.js

'use strict';

const mongoose = require('mongoose');
const Train = require('../models/Train');
const TrainStation = require('../models/TrainStation');

// Optional booking model if present
let TrainBooking = null;
try {
  TrainBooking = require('../models/TrainBooking'); // eslint-disable-line global-require
} catch (e) {
  TrainBooking = null;
}

// ---------- Helpers ----------
function isObjectId(v) {
  return mongoose.Types.ObjectId.isValid(v);
}
function toObjectId(v) {
  return new mongoose.Types.ObjectId(v);
}
function coerceInt(v, def) {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : def;
}
function coerceFloat(v, def) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : def;
}
function toISO(d) {
  return new Date(d).toISOString();
}
function weekdayKey(dateISO) {
  const d = new Date(dateISO);
  // Service days stored as mon..sun; use local interpretation by default
  const day = d.getUTCDay(); // 0=Sun..6=Sat
  return ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][day];
}
async function resolveStationRef(idOrCode) {
  if (!idOrCode) return null;
  if (isObjectId(idOrCode)) {
    const found = await TrainStation.findById(idOrCode).select('_id').lean();
    return found ? String(found._id) : null;
  }
  const byCode = await TrainStation.findOne({ station_code: idOrCode }).select('_id').lean();
  return byCode ? String(byCode._id) : null;
}

// ---------- Search ----------
/**
 * Search trains with GTFS-like semantics:
 * - origin and destination must exist in ordered stops, with origin index < dest index
 * - date must be within validity and enabled by serviceDays
 * - optional filtering by operator/classes and sorting by departure/duration/price/popularity
 */
async function searchTrains({
  origin,                  // stationId or station_code
  destination,             // stationId or station_code
  date,                    // YYYY-MM-DD
  time,                    // optional
  operators,               // comma-separated or array
  classes,                 // comma-separated or array
  sort = 'departure',      // departure | duration | price | popularity
  page = 1,
  limit = 20
}) {
  const originId = await resolveStationRef(origin);
  const destId = await resolveStationRef(destination);
  if (!originId || !destId) {
    return { items: [], page: 1, limit: 0, total: 0, hasMore: false };
  }

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 20), 100);
  const skip = (p - 1) * l;

  const operatorArr = Array.isArray(operators)
    ? operators
    : (operators ? String(operators).split(',').map((s) => s.trim()).filter(Boolean) : []);
  const classArr = Array.isArray(classes)
    ? classes
    : (classes ? String(classes).split(',').map((s) => s.trim()).filter(Boolean) : []);

  const dateISO = date ? new Date(`${date}T00:00:00Z`).toISOString() : null;
  const wk = dateISO ? weekdayKey(dateISO) : null;

  const baseMatch = { isActive: true };
  if (operatorArr.length) baseMatch.operator = { $in: operatorArr };
  if (classArr.length) baseMatch.classes = { $in: classArr };
  if (dateISO) {
    baseMatch['validity.startDate'] = { $lte: new Date(dateISO) };
    baseMatch['validity.endDate'] = { ...(baseMatch['validity.endDate'] || {}), $gte: new Date(dateISO) };
  }
  if (wk) baseMatch[`serviceDays.${wk}`] = true;

  const pipeline = [
    { $match: baseMatch },
    {
      $addFields: {
        _st_stationIds: { $map: { input: '$stops', as: 's', in: '$$s.stationRefId' } }
      }
    },
    {
      $addFields: {
        _idxOrigin: { $indexOfArray: ['$_st_stationIds', new mongoose.Types.ObjectId(originId)] },
        _idxDest: { $indexOfArray: ['$_st_stationIds', new mongoose.Types.ObjectId(destId)] }
      }
    },
    {
      $match: {
        _idxOrigin: { $gte: 0 },
        _idxDest: { $gte: 0 },
        $expr: { $lt: ['$_idxOrigin', '$_idxDest'] }
      }
    },
    {
      $addFields: {
        originStop: { $arrayElemAt: ['$stops', '$_idxOrigin'] },
        destStop: { $arrayElemAt: ['$stops', '$_idxDest'] }
      }
    },
    {
      $addFields: {
        departureISO: '$originStop.dep',
        arrivalISO: '$destStop.arr',
        durationMin: {
          $cond: [
            { $and: ['$originStop.dep', '$destStop.arr'] },
            { $dateDiff: { startDate: '$originStop.dep', endDate: '$destStop.arr', unit: 'minute' } },
            null
          ]
        },
        fareMin: {
          $min: { $map: { input: '$fares', as: 'f', in: '$$f.min' } }
        },
        fareCurrency: {
          $first: { $map: { input: { $slice: ['$fares', 1] }, as: 'f', in: '$$f.currency' } }
        }
      }
    },
    {
      $project: {
        number: 1, name: 1, operator: 1, classes: 1, amenities: 1,
        serviceDays: 1, validity: 1, fares: 1, popularity: 1, viewCount: 1, reviews: 1,
        originStop: 1, destStop: 1, departureISO: 1, arrivalISO: 1, durationMin: 1,
        fareMin: 1, fareCurrency: 1, coordinatesGeoJSON: 1
      }
    }
  ];

  const sortStage = (() => {
    switch (sort) {
      case 'duration': return { durationMin: 1, departureISO: 1 };
      case 'price': return { fareMin: 1, departureISO: 1 };
      case 'popularity': return { popularity: -1, viewCount: -1 };
      case 'departure':
      default: return { departureISO: 1 };
    }
  })();

  pipeline.push({ $sort: sortStage }, { $skip: skip }, { $limit: l });

  const [items, totalAgg] = await Promise.all([
    Train.aggregate(pipeline),
    Train.aggregate([
      { $match: baseMatch },
      { $addFields: { _st_stationIds: { $map: { input: '$stops', as: 's', in: '$$s.stationRefId' } } } },
      { $addFields: {
        _idxOrigin: { $indexOfArray: ['$_st_stationIds', new mongoose.Types.ObjectId(originId)] },
        _idxDest: { $indexOfArray: ['$_st_stationIds', new mongoose.Types.ObjectId(destId)] }
      } },
      { $match: { _idxOrigin: { $gte: 0 }, _idxDest: { $gte: 0 }, $expr: { $lt: ['$_idxOrigin', '$_idxDest'] } } },
      { $count: 'count' }
    ])
  ]);

  const total = totalAgg?.[0]?.count || 0;
  return { items, page: p, limit: l, total, hasMore: skip + items.length < total };
}

// ---------- Suggestions (trains, stations, routes) ----------
async function suggest({ q, types = 'train,station,route', limit = 10 }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const rx = q ? new RegExp(String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;
  const typeSet = new Set(String(types).split(',').map((s) => s.trim()));

  const out = {};

  if (typeSet.has('train')) {
    const match = { isActive: true };
    if (rx) match.$or = [{ number: rx }, { name: rx }, { operator: rx }];
    out.trains = await Train.find(match)
      .select({ _id: 1, number: 1, name: 1, operator: 1, classes: 1 })
      .limit(l)
      .lean();
  }

  if (typeSet.has('station')) {
    const match = { isActive: true };
    if (rx) match.$or = [{ name: rx }, { station_code: rx }, { city: rx }];
    out.stations = await TrainStation.find(match)
      .select({ _id: 1, name: 1, station_code: 1, city: 1, country: 1, location: 1 })
      .limit(l)
      .lean();
  }

  if (typeSet.has('route')) {
    const routes = await Train.aggregate([
      { $project: { _id: 0, number: 1, operator: 1, route: '$number' } },
      ...(rx ? [{ $match: { route: rx } }] : []),
      { $group: { _id: '$route', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: l }
    ]);
    out.routes = routes.map((r) => ({ route: r._id, count: r.count }));
  }

  return out;
}

// ---------- Operators & trending ----------
async function getOperators({ limit = 100 } = {}) {
  const l = Math.min(coerceInt(limit, 100), 200);
  const rows = await Train.aggregate([
    { $match: { isActive: true } },
    {
      $group: {
        _id: '$operator',
        count: { $sum: 1 },
        minFare: { $min: { $min: { $map: { input: '$fares', as: 'f', in: '$$f.min' } } } },
        maxFare: { $max: { $max: { $map: { input: '$fares', as: 'f', in: '$$f.max' } } } }
      }
    },
    { $sort: { count: -1 } },
    { $limit: l }
  ]);
  return rows.map((r) => ({ operator: r._id, count: r.count, fareRange: { min: r.minFare ?? null, max: r.maxFare ?? null } }));
}

async function getTrending({ region, limit = 10 } = {}) {
  const l = Math.min(coerceInt(limit, 10), 50);
  const match = { isActive: true };
  if (region) match['metadata.region'] = region;
  return Train.find(match).sort({ popularity: -1, viewCount: -1 }).limit(l).lean();
}

// ---------- Details ----------
async function getTrainById(id) {
  if (!isObjectId(id)) return null;
  return Train.findById(id).lean();
}

async function getStops(id) {
  const t = await getTrainById(id);
  if (!t) return { stops: [] };
  return { stops: Array.isArray(t.stops) ? t.stops : [] };
}

async function getSchedule(id, { date }) {
  const t = await getTrainById(id);
  if (!t) return { date, active: false, stops: [] };

  let active = true;
  if (date) {
    const dateISO = new Date(`${date}T00:00:00Z`).toISOString();
    const wk = weekdayKey(dateISO);
    if (t.validity?.startDate && new Date(t.validity.startDate).toISOString() > dateISO) active = false;
    if (t.validity?.endDate && new Date(t.validity.endDate).toISOString() < dateISO) active = false;
    if (t.serviceDays && wk && t.serviceDays[wk] === false) active = false;
  }

  return { date: date || null, active, stops: Array.isArray(t.stops) ? t.stops : [] };
}

async function getFares(id) {
  const t = await getTrainById(id);
  if (!t) return { fares: [] };
  return { fares: Array.isArray(t.fares) ? t.fares : [] };
}

// ---------- Geometry ----------
async function getTrainRoute(id) {
  const t = await getTrainById(id);
  if (!t) return { type: 'FeatureCollection', features: [] };

  const g = t.coordinatesGeoJSON;
  if (g?.type === 'FeatureCollection') return g;

  if (g?.type === 'LineString' || g?.type === 'MultiLineString') {
    return { type: 'FeatureCollection', features: [{ type: 'Feature', geometry: g, properties: { id: String(t._id), number: t.number } }] };
  }

  // Fallback: assemble from station points if available
  const stopIds = (t.stops || []).map((s) => s.stationRefId).filter(Boolean).map((x) => new mongoose.Types.ObjectId(x));
  if (stopIds.length) {
    const points = await TrainStation.find({ _id: { $in: stopIds } }).select({ _id: 1, location: 1 }).lean();
    const pMap = new Map(points.map((p) => [String(p._id), p.location?.coordinates]).filter(Boolean));
    const coords = (t.stops || []).map((s) => pMap.get(String(s.stationRefId))).filter(Array.isArray);
    if (coords.length >= 2) {
      return {
        type: 'FeatureCollection',
        features: [{ type: 'Feature', geometry: { type: 'LineString', coordinates: coords }, properties: { id: String(t._id), number: t.number } }]
      };
    }
  }
  return { type: 'FeatureCollection', features: [] };
}

async function getTrainsGeoJSON({ operator, limit = 500 } = {}) {
  const l = Math.min(coerceInt(limit, 500), 2000);
  const match = { isActive: true };
  if (operator) match.operator = operator;

  const items = await Train.find(match).select({ _id: 1, number: 1, operator: 1, coordinatesGeoJSON: 1 }).limit(l).lean();
  const features = [];
  for (const it of items) {
    const g = it.coordinatesGeoJSON;
    if (g?.type === 'LineString' || g?.type === 'MultiLineString') {
      features.push({ type: 'Feature', geometry: g, properties: { id: String(it._id), number: it.number, operator: it.operator } });
    } else if (g?.type === 'FeatureCollection') {
      for (const f of g.features || []) {
        features.push({ type: 'Feature', geometry: f.geometry, properties: { id: String(it._id), number: it.number, operator: it.operator } });
      }
    }
  }
  return { type: 'FeatureCollection', features };
}

/**
 * BBox query using $geoIntersects against route LineStrings to fetch lines crossing the viewport.
 */
async function getByBBox({ minLng, minLat, maxLng, maxLat, limit = 500, filters = {} }) {
  const l = Math.min(coerceInt(limit, 500), 2000);
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

  const match = { isActive: true, ...filters };
  match.coordinatesGeoJSON = { $geoIntersects: { $geometry: polygon } };

  const rows = await Train.find(match).select({ _id: 1, number: 1, operator: 1, coordinatesGeoJSON: 1 }).limit(l).lean();
  return rows;
}

// ---------- Live status (stub) ----------
async function getLiveStatus({ operator, number, date }) {
  return {
    operator: operator || null,
    number: number || null,
    date: date || null,
    status: 'unknown',
    lastUpdatedISO: toISO(Date.now())
  };
}

// ---------- Seat map & availability ----------
function generateSeatMap({ classCode = 'STD', coaches = 3, rowsPerCoach = 12 }) {
  const maps = [];
  for (let c = 1; c <= coaches; c++) {
    const seatsPerRow = classCode === '3A' || classCode === '2A' ? 6 : 8; // heuristic berth/row mix
    const layout = [];
    for (let r = 1; r <= rowsPerCoach; r++) {
      const row = [];
      for (let s = 0; s < seatsPerRow; s++) {
        row.push({ seat: `${c}-${r}${String.fromCharCode(65 + s)}`, available: true });
      }
      layout.push(row);
    }
    maps.push({ coach: `${classCode}-${c}`, rows: rowsPerCoach, cols: seatsPerRow, layout });
  }
  return { classCode, coaches: maps };
}

async function getSeatMap({ id, date, classCode = 'STD' }) {
  const t = await getTrainById(id);
  if (!t) return null;
  return generateSeatMap({ classCode });
}

async function getAvailability({ id, date, classCode, quota }) {
  const t = await getTrainById(id);
  if (!t) return { available: false };

  const dateISO = date ? new Date(`${date}T00:00:00Z`).toISOString() : null;
  let active = true;
  if (dateISO) {
    const wk = weekdayKey(dateISO);
    if (t.validity?.startDate && new Date(t.validity.startDate).toISOString() > dateISO) active = false;
    if (t.validity?.endDate && new Date(t.validity.endDate).toISOString() < dateISO) active = false;
    if (t.serviceDays && wk && t.serviceDays[wk] === false) active = false;
  }

  const classExists = classCode ? Array.isArray(t.classes) && t.classes.includes(classCode) : true;
  return { active, classCode: classCode || null, quota: quota || null, available: active && classExists };
}

// ---------- Quote & Booking ----------
async function getQuote({
  trainId,
  date,                      // YYYY-MM-DD (ISO-friendly)
  classCode,
  originStopSeq,             // preferred
  destinationStopSeq,
  passengers = 1,
  currency
}) {
  const t = await getTrainById(trainId);
  if (!t) return null;

  const fares = Array.isArray(t.fares) ? t.fares : [];
  let fare = null;
  if (classCode) fare = fares.find((f) => f.classCode === classCode) || null;
  if (!fare) {
    fare = fares.reduce((acc, f) => (acc && acc.min <= (f.min ?? Infinity) ? acc : f), null);
  }
  if (!fare) return null;

  const unit = fare.min ?? 0;
  const curr = currency || fare.currency || 'INR';
  const qty = coerceInt(passengers, 1);

  const holdExpiryISO = toISO(Date.now() + 15 * 60 * 1000);
  return {
    trainId: String(t._id),
    number: t.number,
    operator: t.operator,
    date: date || null,
    classCode: fare.classCode,
    originStopSeq: originStopSeq ?? null,
    destinationStopSeq: destinationStopSeq ?? null,
    passengers: qty,
    price: { currency: curr, unitAmount: unit, totalAmount: unit * qty },
    holdExpiryISO
  };
}

async function bookTrain(id, { quote, contact, passengers, payment }) {
  const t = await getTrainById(id);
  if (!t) return null;

  const payload = {
    trainId: String(t._id),
    number: t.number,
    operator: t.operator,
    quote,
    contact,
    passengers,
    state: 'confirmed',
    createdAtISO: toISO(Date.now()),
    payment: payment ? { ...payment, state: 'captured' } : { state: 'pending' }
  };

  if (TrainBooking) {
    const saved = await TrainBooking.create(payload);
    return saved.toObject();
  }
  return { _id: null, ...payload };
}

// ---------- Convenience: trains serving a station ----------
async function getTrainsByStation(stationId, { date }) {
  const ref = await resolveStationRef(stationId);
  if (!ref) return { items: [] };

  const dateISO = date ? new Date(`${date}T00:00:00Z`).toISOString() : null;
  const wk = dateISO ? weekdayKey(dateISO) : null;

  const match = { isActive: true };
  if (dateISO) {
    match['validity.startDate'] = { $lte: new Date(dateISO) };
    match['validity.endDate'] = { ...(match['validity.endDate'] || {}), $gte: new Date(dateISO) };
  }
  if (wk) match[`serviceDays.${wk}`] = true;

  const items = await Train.aggregate([
    { $match: match },
    {
      $addFields: {
        _st_stationIds: { $map: { input: '$stops', as: 's', in: '$$s.stationRefId' } },
        _st_arrivals: { $map: { input: '$stops', as: 's', in: { stationRefId: '$$s.stationRefId', arr: '$$s.arr', dep: '$$s.dep', seq: '$$s.seq' } } }
      }
    },
    {
      $addFields: {
        _idx: { $indexOfArray: ['$_st_stationIds', new mongoose.Types.ObjectId(ref)] }
      }
    },
    { $match: { _idx: { $gte: 0 } } },
    {
      $addFields: {
        stopAt: { $arrayElemAt: ['$_st_arrivals', '$_idx'] }
      }
    },
    {
      $project: {
        number: 1, name: 1, operator: 1, classes: 1, popularity: 1, viewCount: 1,
        arrivalISO: '$stopAt.arr', departureISO: '$stopAt.dep', seq: '$stopAt.seq'
      }
    },
    { $sort: { departureISO: 1 } }
  ]);

  return { items };
}

module.exports = {
  // search/suggest
  searchTrains,
  suggest,
  getOperators,
  getTrending,

  // details
  getTrainById,
  getStops,
  getSchedule,
  getFares,

  // geometry
  getTrainRoute,
  getTrainsGeoJSON,
  getByBBox,

  // realtime/ux
  getLiveStatus,
  getSeatMap,
  getAvailability,

  // commerce
  getQuote,
  bookTrain,

  // stations
  getTrainsByStation
};
