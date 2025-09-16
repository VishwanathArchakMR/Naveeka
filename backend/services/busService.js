// C:\flutterapp\myapp\backend\services\busService.js

'use strict';

const mongoose = require('mongoose');
const Bus = require('../models/Bus');
const BusStop = require('../models/BusStop');

function isObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
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
  const day = d.getUTCDay(); // 0=Sun ... 6=Sat
  return ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][day];
}

async function resolveStopRef(idOrCode) {
  if (!idOrCode) return null;
  if (isObjectId(idOrCode)) {
    const found = await BusStop.findById(idOrCode).select('_id').lean();
    return found ? String(found._id) : null;
  }
  const byCode = await BusStop.findOne({ stop_code: idOrCode }).select('_id').lean();
  return byCode ? String(byCode._id) : null;
}

/**
 * Search buses by origin/destination/date with optional operator/class filters.
 * Applies validity window and service-days constraints, and ensures origin precedes destination in the stops array.
 */
async function searchBuses({
  origin,                  // stationId or stop_code
  destination,             // stationId or stop_code
  date,                    // YYYY-MM-DD
  time,                    // optional, not strictly enforced here
  operators,               // comma-separated or array
  classes,                 // comma-separated or array
  sort = 'departure',      // departure | duration | price | popularity
  page = 1,
  limit = 20
}) {
  const originId = await resolveStopRef(origin);
  const destId = await resolveStopRef(destination);
  if (!originId || !destId) {
    return { items: [], page: 1, limit: 0, total: 0, hasMore: false };
  }

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 20), 100);
  const skip = (p - 1) * l;

  // Filters
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
  if (wk) {
    baseMatch[`serviceDays.${wk}`] = true;
  }

  // Build pipeline to ensure origin < destination in stops
  const pipeline = [
    { $match: baseMatch },
    {
      $addFields: {
        _st_stationIds: {
          $map: {
            input: '$stops',
            as: 's',
            in: '$$s.stationRefId'
          }
        }
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
    // Lift origin/dest sub-docs and compute times/duration
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
            {
              $dateDiff: {
                startDate: '$originStop.dep',
                endDate: '$destStop.arr',
                unit: 'minute'
              }
            },
            null
          ]
        }
      }
    },
    // Compute cheapest fare in pipeline for quick cards
    {
      $addFields: {
        fareMin: {
          $min: {
            $map: { input: '$fares', as: 'f', in: '$$f.min' }
          }
        },
        fareCurrency: {
          $first: {
            $map: { input: { $slice: ['$fares', 1] }, as: 'f', in: '$$f.currency' }
          }
        }
      }
    },
    {
      $project: {
        number: 1,
        name: 1,
        operator: 1,
        classes: 1,
        amenities: 1,
        serviceDays: 1,
        validity: 1,
        fares: 1,
        popularity: 1,
        viewCount: 1,
        reviews: 1,
        departureISO: 1,
        arrivalISO: 1,
        durationMin: 1,
        originStop: 1,
        destStop: 1,
        fareMin: 1,
        fareCurrency: 1,
        coordinatesGeoJSON: 1
      }
    }
  ];

  // Sorting
  const sortStage = (() => {
    switch (sort) {
      case 'duration':
        return { durationMin: 1, departureISO: 1 };
      case 'price':
        return { fareMin: 1, departureISO: 1 };
      case 'popularity':
        return { popularity: -1, viewCount: -1 };
      case 'departure':
      default:
        return { departureISO: 1 };
    }
  })();

  pipeline.push({ $sort: sortStage });
  pipeline.push({ $skip: skip });
  pipeline.push({ $limit: l });

  const [items, totalAgg] = await Promise.all([
    Bus.aggregate(pipeline),
    Bus.aggregate([
      { $match: baseMatch },
      {
        $addFields: {
          _st_stationIds: {
            $map: { input: '$stops', as: 's', in: '$$s.stationRefId' }
          }
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
          $expr: { $lt: ['$_idxOrigin', '_idxDest'] }
        }
      },
      { $count: 'count' }
    ])
  ]);

  const total = totalAgg?.[0]?.count || 0;
  return {
    items,
    page: p,
    limit: l,
    total,
    hasMore: skip + items.length < total
  };
}

async function suggestBuses({ q, limit = 10, operator }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const regex = q ? new RegExp(String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;

  const match = { isActive: true };
  if (regex) {
    match.$or = [{ number: regex }, { name: regex }, { operator: regex }];
  }
  if (operator) match.operator = operator;

  const items = await Bus.find(match)
    .select({ _id: 1, number: 1, name: 1, operator: 1, classes: 1 })
    .limit(l)
    .lean();

  return items;
}

async function getOperators({ limit = 100 } = {}) {
  const l = Math.min(coerceInt(limit, 100), 200);
  const rows = await Bus.aggregate([
    { $match: { isActive: true } },
    {
      $group: {
        _id: '$operator',
        count: { $sum: 1 },
        minFare: {
          $min: {
            $min: {
              $map: { input: '$fares', as: 'f', in: '$$f.min' }
            }
          }
        },
        maxFare: {
          $max: {
            $max: {
              $map: { input: '$fares', as: 'f', in: '$$f.max' }
            }
          }
        }
      }
    },
    { $sort: { count: -1 } },
    { $limit: l }
  ]);

  return rows.map((r) => ({
    operator: r._id,
    count: r.count,
    fareRange: { min: r.minFare ?? null, max: r.maxFare ?? null }
  }));
}

async function getTrending({ region, limit = 10 } = {}) {
  const l = Math.min(coerceInt(limit, 10), 50);
  const match = { isActive: true };
  if (region) match['metadata.region'] = region;

  const items = await Bus.find(match)
    .sort({ popularity: -1, viewCount: -1 })
    .limit(l)
    .lean();

  return items;
}

async function getBusById(id) {
  if (!isObjectId(id)) return null;
  return Bus.findById(id).lean();
}

async function getBusRoute(busId) {
  const bus = await getBusById(busId);
  if (!bus) return null;

  // Use precomputed GeoJSON if present; fallback to building from stops + BusStop points
  if (bus.coordinatesGeoJSON?.type === 'LineString') {
    return {
      type: 'FeatureCollection',
      features: [
        { type: 'Feature', geometry: bus.coordinatesGeoJSON, properties: { id: String(bus._id), number: bus.number, operator: bus.operator } }
      ]
    };
  }

  // Fallback: attempt to assemble LineString from stop coordinates
  const stopIds = (bus.stops || [])
    .map((s) => s.stationRefId)
    .filter(Boolean)
    .map((id) => new mongoose.Types.ObjectId(id));
  const points = await BusStop.find({ _id: { $in: stopIds } })
    .select({ _id: 1, location: 1 })
    .lean();

  const coordMap = new Map(points.map((p) => [String(p._id), p.location?.coordinates].filter(Boolean)));
  const coords = (bus.stops || [])
    .map((s) => coordMap.get(String(s.stationRefId)))
    .filter(Array.isArray);

  if (coords.length >= 2) {
    return {
      type: 'FeatureCollection',
      features: [
        {
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: coords },
          properties: { id: String(bus._id), number: bus.number, operator: bus.operator }
        }
      ]
    };
  }

  // If still not enough, return empty FeatureCollection
  return { type: 'FeatureCollection', features: [] };
}

/**
 * Multi-entity GeoJSON for buses, returning route polylines when available.
 */
async function getBusesGeoJSON({ operator, limit = 500 } = {}) {
  const l = Math.min(coerceInt(limit, 500), 2000);
  const match = { isActive: true };
  if (operator) match.operator = operator;

  const items = await Bus.find(match)
    .select({ _id: 1, number: 1, operator: 1, coordinatesGeoJSON: 1 })
    .limit(l)
    .lean();

  const features = [];
  for (const b of items) {
    if (b.coordinatesGeoJSON?.type === 'LineString') {
      features.push({
        type: 'Feature',
        geometry: b.coordinatesGeoJSON,
        properties: { id: String(b._id), number: b.number, operator: b.operator }
      });
    }
  }

  return { type: 'FeatureCollection', features };
}

/**
 * Live status stub for a bus trip id.
 * Integrate provider telemetry here (positions/ETA) if available.
 */
async function getLiveStatus(busId) {
  const bus = await getBusById(busId);
  if (!bus) return null;

  // Placeholder without real telemetry
  return {
    busId: String(bus._id),
    number: bus.number,
    operator: bus.operator,
    lastKnown: null,
    etaMinutes: null
  };
}

/**
 * Simple seat-map generator when upstream provider doesn't supply layouts.
 * Produces a 2x2 per row layout for STD, and 2x1 for AC as a default heuristic.
 */
function generateSeatMap({ classCode = 'STD', rows = 12 }) {
  const layout = [];
  const seatsPerRow = classCode === 'AC' ? 3 : 4; // heuristic: AC often 2+1, STD 2+2
  let seatNum = 1;
  for (let r = 1; r <= rows; r++) {
    const row = [];
    for (let c = 0; c < seatsPerRow; c++) {
      row.push({
        seat: `${r}${String.fromCharCode(65 + c)}`,
        available: true
      });
      seatNum++;
    }
    layout.push(row);
  }
  return { classCode, rows: layout.length, cols: seatsPerRow, layout };
}

/**
 * Seat map for a given bus and class.
 */
async function getSeatMap({ busId, classCode = 'STD' }) {
  const bus = await getBusById(busId);
  if (!bus) return null;

  // If bus has a provider seat-map, return it here (not modeled in demo)
  return generateSeatMap({ classCode });
}

/**
 * Fare quote for a bus: picks fare for requested class or cheapest available.
 * Returns ISO 8601 hold expiry for UI countdown.
 */
async function getFareQuote({
  busId,
  classCode,
  passengers = 1,
  currency // optional override
}) {
  const bus = await getBusById(busId);
  if (!bus) return null;

  const fares = Array.isArray(bus.fares) ? bus.fares : [];
  let fare = null;

  if (classCode) {
    fare = fares.find((f) => f.classCode === classCode) || null;
  }
  if (!fare) {
    // cheapest
    fare = fares.reduce((acc, f) => {
      const m = typeof f.min === 'number' ? f.min : Number.MAX_SAFE_INTEGER;
      if (!acc || m < acc.min) return f;
      return acc;
    }, null);
  }
  if (!fare) return null;

  const unit = fare.min ?? 0;
  const curr = currency || fare.currency || 'INR';
  const qty = coerceInt(passengers, 1);
  const total = unit * qty;

  return {
    busId: String(bus._id),
    number: bus.number,
    operator: bus.operator,
    classCode: fare.classCode,
    passengers: qty,
    price: { currency: curr, unitAmount: unit, totalAmount: total },
    holdExpiryISO: toISO(Date.now() + 15 * 60 * 1000)
  };
}

module.exports = {
  searchBuses,
  suggestBuses,
  getOperators,
  getTrending,
  getBusById,
  getBusRoute,
  getBusesGeoJSON,
  getLiveStatus,
  getSeatMap,
  getFareQuote
};
