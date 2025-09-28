// backend/services/cacheService.js

/* eslint-disable no-console */
let createClient = null;
let redisAvailable = false;
try {
  // Lazy/safe require so the app does not crash if 'redis' is not installed
  ({ createClient } = require('redis'));
  redisAvailable = typeof createClient === 'function';
} catch (_) {
  redisAvailable = false;
}

/**
 * A small in-memory cache fallback with TTL and max size.
 */
class MemoryCache {
  constructor({ maxItems = 1000 } = {}) {
    this.maxItems = maxItems;
    this.store = new Map(); // key -> { value, expireAt }
  }

  _evictIfNeeded() {
    if (this.store.size <= this.maxItems) return;
    const over = this.store.size - this.maxItems;
    let i = 0;
    for (const k of this.store.keys()) {
      this.store.delete(k);
      if (++i >= over) break;
    }
  }

  async get(key) {
    const now = Date.now();
    const entry = this.store.get(key);
    if (!entry) return null;
    if (entry.expireAt && entry.expireAt <= now) {
      this.store.delete(key);
      return null;
    }
    return entry.value;
  }

  async set(key, value, ttlSec) {
    const expireAt = ttlSec ? Date.now() + ttlSec * 1000 : null;
    this.store.set(key, { value, expireAt });
    this._evictIfNeeded();
    return 'OK';
  }

  async del(key) {
    return this.store.delete(key) ? 1 : 0;
  }

  async clearNamespace(prefix) {
    for (const k of this.store.keys()) {
      if (k.startsWith(prefix)) {
        this.store.delete(k);
      }
    }
  }

  async size() {
    return this.store.size;
  }
}

class CacheService {
  /**
   * @param {Object} options
   * @param {string} [options.namespace='naveeka'] key prefix
   * @param {number} [options.defaultTtl=300] default TTL in seconds
   * @param {number} [options.memoryMaxItems=1000] in-memory fallback max items
   * @param {string} [options.redisUrl=process.env.REDIS_URL] Redis URL like redis://localhost:6379
   */
  constructor({
    namespace = 'naveeka',
    defaultTtl = 300,
    memoryMaxItems = 1000,
    redisUrl = process.env.REDIS_URL,
  } = {}) {
    this.namespace = namespace;
    this.defaultTtl = defaultTtl;
    this.redisUrl = redisUrl;
    this.mem = new MemoryCache({ maxItems: memoryMaxItems });

    this.client = null;
    this.connected = false;
    this._connecting = null;
    this._redisEnabled = Boolean(redisAvailable && this.redisUrl);
  }

  _k(key) {
    return `${this.namespace}:${key}`;
  }

  async connect() {
    // No Redis configured or module unavailable: always fallback to memory
    if (!this._redisEnabled) {
      this.connected = false;
      return;
    }

    if (this.connected) return;
    if (this._connecting) return this._connecting;

    this._connecting = (async () => {
      try {
        this.client = createClient({ url: this.redisUrl });

        this.client.on('error', (err) => {
          this.connected = false;
          console.error('[cacheService] Redis error:', err);
        });

        this.client.on('ready', () => {
          this.connected = true;
          console.log('[cacheService] Redis ready:', this.redisUrl);
        });

        await this.client.connect();
      } catch (err) {
        this.connected = false;
        console.warn('[cacheService] Redis connect failed, using memory fallback:', err.message);
      }
    })();

    try {
      await this._connecting;
    } finally {
      this._connecting = null;
    }
  }

  async get(key) {
    await this.connect();
    const k = this._k(key);
    if (this.connected && this.client) {
      const s = await this.client.get(k);
      return s ? JSON.parse(s) : null;
    }
    return this.mem.get(k);
  }

  async set(key, value, ttlSec = this.defaultTtl) {
    await this.connect();
    const k = this._k(key);
    const payload = JSON.stringify(value);
    if (this.connected && this.client) {
      if (ttlSec && ttlSec > 0) {
        return this.client.set(k, payload, { EX: ttlSec });
      }
      return this.client.set(k, payload);
    }
    return this.mem.set(k, value, ttlSec);
  }

  async del(key) {
    await this.connect();
    const k = this._k(key);
    if (this.connected && this.client) {
      return this.client.del(k);
    }
    return this.mem.del(k);
  }

  /**
   * Acquire a simple lock to prevent stampede (SET NX EX). [Atomic lock with NX/EX]
   */
  async tryLock(key, ttlSec = 10) {
    await this.connect();
    const lockKey = this._k(`lock:${key}`);
    if (this.connected && this.client) {
      const res = await this.client.set(lockKey, '1', { NX: true, EX: ttlSec });
      return res === 'OK';
    }
    const v = await this.mem.get(lockKey);
    if (v) return false;
    await this.mem.set(lockKey, '1', ttlSec);
    return true;
  }

  async unlock(key) {
    const lockKey = this._k(`lock:${key}`);
    if (this.connected && this.client) {
      try {
        await this.client.del(lockKey);
      } catch {
        // ignore
      }
    } else {
      await this.mem.del(lockKey);
    }
  }

  /**
   * Wrap a fetcher call with cache using a lock to avoid thundering herds.
   */
  async withCache(
    key,
    fetcher,
    { ttlSec = this.defaultTtl, lockTtlSec = 10, waitMs = 3000, pollIntervalMs = 100 } = {}
  ) {
    const cached = await this.get(key);
    if (cached !== null && cached !== undefined) return cached;

    const gotLock = await this.tryLock(key, lockTtlSec);
    if (gotLock) {
      try {
        const fresh = await fetcher();
        await this.set(key, fresh, ttlSec);
        return fresh;
      } finally {
        await this.unlock(key);
      }
    }

    const started = Date.now();
    while (Date.now() - started < waitMs) {
      await new Promise((r) => setTimeout(r, pollIntervalMs));
      const again = await this.get(key);
      if (again !== null && again !== undefined) return again;
    }

    const fresh = await fetcher();
    await this.set(key, fresh, ttlSec);
    return fresh;
  }

  /**
   * Flush all keys under this namespace using SCAN to avoid KEYS blocking. [SCAN iteration]
   */
  async flushNamespace() {
    await this.connect();
    const prefix = `${this.namespace}:`;

    if (!this.connected || !this.client) {
      await this.mem.clearNamespace(prefix);
      return 0;
    }

    let cursor = '0';
    let total = 0;
    do {
      // node-redis v4 returns { cursor, keys }
      const res = await this.client.scan(cursor, { MATCH: `${prefix}*`, COUNT: 1000 });
      cursor = res.cursor ?? (Array.isArray(res) ? res[0] : '0');
      const keys = res.keys ?? (Array.isArray(res) ? res[1] : []);
      if (keys && keys.length) {
        total += await this.client.del(keys);
      }
    } while (cursor !== '0');

    return total;
  }

  async info() {
    return {
      namespace: this.namespace,
      redisConfigured: this._redisEnabled,
      redisConnected: this.connected,
      memoryItems: await this.mem.size(),
      defaultTtl: this.defaultTtl,
    };
  }
}

const cacheService = new CacheService();

module.exports = {
  CacheService,
  cacheService,
};
