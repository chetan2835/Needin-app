// deno-lint-ignore-file no-explicit-any
// ══════════════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — PRODUCTION PRICING ENGINE v3.0
//  POST /calculate-price
//  Backend-first, stateless, single source of truth
//
//  PRIORITY ORDER:
//  1. Flight → fixed override (ignore everything)
//  2. Same City → fixed floor pricing
//  3. City-to-City → slab-based lookup (1–3000 KM)
//
//  ETR System: Time₁ (Google Maps driving) + 10% grace
//  Time₁ ALWAYS uses CAR/DRIVING mode regardless of travel_mode
// ══════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ── TYPES ───────────────────────────────────────────────────────────

interface SlabEntry {
  minKm: number;
  maxKm: number;
  underTime: number;
  delay60: number;
  delayAbove60: number;
}

interface RouteData {
  distance_km: number;
  duration_text: string;
  duration_seconds: number;
  origin_city: string;
  destination_city: string;
}

interface PricingRequest {
  origin_lat: number;
  origin_lng: number;
  destination_lat: number;
  destination_lng: number;
  parcel_size: string;
  travel_mode: string;
  time_performance?: string;
}

// ── CORS HEADERS ────────────────────────────────────────────────────

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

// ── GOOGLE MAPS API KEY ─────────────────────────────────────────────

const GOOGLE_MAPS_API_KEY = Deno.env.get("GOOGLE_MAPS_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// ══════════════════════════════════════════════════════════════════════
//  OFFICIAL PRICING DATA — EXACT MATCH TO SPEC
// ══════════════════════════════════════════════════════════════════════

// ── SAME CITY FIXED PRICING (Floor Model) ──────────────────────────
// ₹99 × 0.5 = ₹49.5 → Floor → ₹49 base
const SAME_CITY_PRICES: Record<string, Record<string, number>> = {
  small:  { under_time: 49, delay_60: 49, delay_above_60: 49 },
  medium: { under_time: 79, delay_60: 69, delay_above_60: 59 },
  large:  { under_time: 99, delay_60: 89, delay_above_60: 79 },
};

// ── FLIGHT FIXED PRICING ───────────────────────────────────────────
// Flight ignores ALL other logic
const FLIGHT_PRICES: Record<string, number> = {
  micro: 449,
  small: 649,
  medium: 949,
};

// ── SMALL PARCEL (A) — 1–1200 KM ──────────────────────────────────
const SMALL_SLABS_1200: SlabEntry[] = [
  { minKm: 1,    maxKm: 100,  underTime: 99,  delay60: 89,  delayAbove60: 79 },
  { minKm: 101,  maxKm: 200,  underTime: 129, delay60: 109, delayAbove60: 99 },
  { minKm: 201,  maxKm: 300,  underTime: 159, delay60: 139, delayAbove60: 119 },
  { minKm: 301,  maxKm: 400,  underTime: 189, delay60: 159, delayAbove60: 139 },
  { minKm: 401,  maxKm: 500,  underTime: 219, delay60: 189, delayAbove60: 169 },
  { minKm: 501,  maxKm: 600,  underTime: 249, delay60: 209, delayAbove60: 189 },
  { minKm: 601,  maxKm: 700,  underTime: 279, delay60: 239, delayAbove60: 209 },
  { minKm: 701,  maxKm: 800,  underTime: 309, delay60: 259, delayAbove60: 229 },
  { minKm: 801,  maxKm: 900,  underTime: 339, delay60: 289, delayAbove60: 259 },
  { minKm: 901,  maxKm: 1000, underTime: 369, delay60: 319, delayAbove60: 279 },
  { minKm: 1001, maxKm: 1100, underTime: 399, delay60: 339, delayAbove60: 299 },
  { minKm: 1101, maxKm: 1200, underTime: 429, delay60: 369, delayAbove60: 319 },
];

// ── SMALL PARCEL (A) — 1201–3000 KM ───────────────────────────────
const SMALL_SLABS_3000: SlabEntry[] = [
  { minKm: 1201, maxKm: 1300, underTime: 449, delay60: 379, delayAbove60: 339 },
  { minKm: 1301, maxKm: 1400, underTime: 469, delay60: 399, delayAbove60: 349 },
  { minKm: 1401, maxKm: 1500, underTime: 489, delay60: 419, delayAbove60: 369 },
  { minKm: 1501, maxKm: 1600, underTime: 509, delay60: 429, delayAbove60: 379 },
  { minKm: 1601, maxKm: 1700, underTime: 529, delay60: 449, delayAbove60: 399 },
  { minKm: 1701, maxKm: 1800, underTime: 549, delay60: 469, delayAbove60: 409 },
  { minKm: 1801, maxKm: 1900, underTime: 569, delay60: 479, delayAbove60: 429 },
  { minKm: 1901, maxKm: 2000, underTime: 589, delay60: 499, delayAbove60: 439 },
  { minKm: 2001, maxKm: 2100, underTime: 609, delay60: 519, delayAbove60: 459 },
  { minKm: 2101, maxKm: 2200, underTime: 629, delay60: 529, delayAbove60: 469 },
  { minKm: 2201, maxKm: 2300, underTime: 649, delay60: 549, delayAbove60: 489 },
  { minKm: 2301, maxKm: 2400, underTime: 669, delay60: 569, delayAbove60: 499 },
  { minKm: 2401, maxKm: 2500, underTime: 689, delay60: 579, delayAbove60: 519 },
  { minKm: 2501, maxKm: 2600, underTime: 709, delay60: 599, delayAbove60: 529 },
  { minKm: 2601, maxKm: 2700, underTime: 729, delay60: 619, delayAbove60: 549 },
  { minKm: 2701, maxKm: 2800, underTime: 749, delay60: 629, delayAbove60: 559 },
  { minKm: 2801, maxKm: 2900, underTime: 769, delay60: 649, delayAbove60: 579 },
  { minKm: 2901, maxKm: 3000, underTime: 789, delay60: 669, delayAbove60: 589 },
];

// ── MEDIUM PARCEL (B) — 1–1200 KM ─────────────────────────────────
const MEDIUM_SLABS_1200: SlabEntry[] = [
  { minKm: 1,    maxKm: 100,  underTime: 149, delay60: 129, delayAbove60: 109 },
  { minKm: 101,  maxKm: 200,  underTime: 189, delay60: 159, delayAbove60: 139 },
  { minKm: 201,  maxKm: 300,  underTime: 239, delay60: 209, delayAbove60: 179 },
  { minKm: 301,  maxKm: 400,  underTime: 279, delay60: 239, delayAbove60: 209 },
  { minKm: 401,  maxKm: 500,  underTime: 329, delay60: 279, delayAbove60: 249 },
  { minKm: 501,  maxKm: 600,  underTime: 369, delay60: 319, delayAbove60: 279 },
  { minKm: 601,  maxKm: 700,  underTime: 419, delay60: 359, delayAbove60: 319 },
  { minKm: 701,  maxKm: 800,  underTime: 459, delay60: 389, delayAbove60: 349 },
  { minKm: 801,  maxKm: 900,  underTime: 509, delay60: 429, delayAbove60: 379 },
  { minKm: 901,  maxKm: 1000, underTime: 549, delay60: 469, delayAbove60: 409 },
  { minKm: 1001, maxKm: 1100, underTime: 599, delay60: 509, delayAbove60: 449 },
  { minKm: 1101, maxKm: 1200, underTime: 639, delay60: 539, delayAbove60: 479 },
];

// ── MEDIUM PARCEL (B) — 1201–3000 KM ──────────────────────────────
const MEDIUM_SLABS_3000: SlabEntry[] = [
  { minKm: 1201, maxKm: 1300, underTime: 669, delay60: 569, delayAbove60: 499 },
  { minKm: 1301, maxKm: 1400, underTime: 699, delay60: 589, delayAbove60: 519 },
  { minKm: 1401, maxKm: 1500, underTime: 729, delay60: 619, delayAbove60: 549 },
  { minKm: 1501, maxKm: 1600, underTime: 759, delay60: 649, delayAbove60: 569 },
  { minKm: 1601, maxKm: 1700, underTime: 789, delay60: 669, delayAbove60: 589 },
  { minKm: 1701, maxKm: 1800, underTime: 819, delay60: 699, delayAbove60: 609 },
  { minKm: 1801, maxKm: 1900, underTime: 849, delay60: 719, delayAbove60: 629 },
  { minKm: 1901, maxKm: 2000, underTime: 879, delay60: 749, delayAbove60: 659 },
  { minKm: 2001, maxKm: 2100, underTime: 909, delay60: 769, delayAbove60: 679 },
  { minKm: 2101, maxKm: 2200, underTime: 939, delay60: 799, delayAbove60: 699 },
  { minKm: 2201, maxKm: 2300, underTime: 969, delay60: 819, delayAbove60: 719 },
  { minKm: 2301, maxKm: 2400, underTime: 999, delay60: 849, delayAbove60: 749 },
  { minKm: 2401, maxKm: 2500, underTime: 1029, delay60: 869, delayAbove60: 769 },
  { minKm: 2501, maxKm: 2600, underTime: 1059, delay60: 899, delayAbove60: 789 },
  { minKm: 2601, maxKm: 2700, underTime: 1089, delay60: 919, delayAbove60: 819 },
  { minKm: 2701, maxKm: 2800, underTime: 1119, delay60: 949, delayAbove60: 839 },
  { minKm: 2801, maxKm: 2900, underTime: 1149, delay60: 969, delayAbove60: 869 },
  { minKm: 2901, maxKm: 3000, underTime: 1179, delay60: 999, delayAbove60: 889 },
];

// ── LARGE PARCEL (C) — 1–1200 KM ──────────────────────────────────
const LARGE_SLABS_1200: SlabEntry[] = [
  { minKm: 1,    maxKm: 100,  underTime: 199, delay60: 169, delayAbove60: 149 },
  { minKm: 101,  maxKm: 200,  underTime: 259, delay60: 219, delayAbove60: 199 },
  { minKm: 201,  maxKm: 300,  underTime: 319, delay60: 269, delayAbove60: 239 },
  { minKm: 301,  maxKm: 400,  underTime: 379, delay60: 319, delayAbove60: 279 },
  { minKm: 401,  maxKm: 500,  underTime: 439, delay60: 369, delayAbove60: 319 },
  { minKm: 501,  maxKm: 600,  underTime: 499, delay60: 419, delayAbove60: 369 },
  { minKm: 601,  maxKm: 700,  underTime: 559, delay60: 469, delayAbove60: 409 },
  { minKm: 701,  maxKm: 800,  underTime: 619, delay60: 519, delayAbove60: 459 },
  { minKm: 801,  maxKm: 900,  underTime: 679, delay60: 569, delayAbove60: 499 },
  { minKm: 901,  maxKm: 1000, underTime: 739, delay60: 619, delayAbove60: 549 },
  { minKm: 1001, maxKm: 1100, underTime: 799, delay60: 669, delayAbove60: 599 },
  { minKm: 1101, maxKm: 1200, underTime: 859, delay60: 719, delayAbove60: 639 },
];

// ── LARGE PARCEL (C) — 1201–3000 KM ───────────────────────────────
const LARGE_SLABS_3000: SlabEntry[] = [
  { minKm: 1201, maxKm: 1300, underTime: 899, delay60: 759, delayAbove60: 679 },
  { minKm: 1301, maxKm: 1400, underTime: 939, delay60: 799, delayAbove60: 699 },
  { minKm: 1401, maxKm: 1500, underTime: 979, delay60: 829, delayAbove60: 739 },
  { minKm: 1501, maxKm: 1600, underTime: 1019, delay60: 869, delayAbove60: 759 },
  { minKm: 1601, maxKm: 1700, underTime: 1059, delay60: 899, delayAbove60: 789 },
  { minKm: 1701, maxKm: 1800, underTime: 1099, delay60: 939, delayAbove60: 819 },
  { minKm: 1801, maxKm: 1900, underTime: 1139, delay60: 969, delayAbove60: 849 },
  { minKm: 1901, maxKm: 2000, underTime: 1179, delay60: 999, delayAbove60: 879 },
  { minKm: 2001, maxKm: 2100, underTime: 1219, delay60: 1039, delayAbove60: 919 },
  { minKm: 2101, maxKm: 2200, underTime: 1259, delay60: 1069, delayAbove60: 949 },
  { minKm: 2201, maxKm: 2300, underTime: 1299, delay60: 1109, delayAbove60: 979 },
  { minKm: 2301, maxKm: 2400, underTime: 1339, delay60: 1139, delayAbove60: 1009 },
  { minKm: 2401, maxKm: 2500, underTime: 1379, delay60: 1169, delayAbove60: 1039 },
  { minKm: 2501, maxKm: 2600, underTime: 1419, delay60: 1209, delayAbove60: 1069 },
  { minKm: 2601, maxKm: 2700, underTime: 1459, delay60: 1239, delayAbove60: 1109 },
  { minKm: 2701, maxKm: 2800, underTime: 1499, delay60: 1279, delayAbove60: 1139 },
  { minKm: 2801, maxKm: 2900, underTime: 1539, delay60: 1309, delayAbove60: 1169 },
  { minKm: 2901, maxKm: 3000, underTime: 1579, delay60: 1349, delayAbove60: 1189 },
];

// ── LRU ROUTE CACHE ────────────────────────────────────────────────

class LRUCache<K, V> {
  private maxSize: number;
  private ttlMs: number;
  private cache: Map<K, { value: V; ts: number }>;

  constructor(maxSize: number, ttlMs: number) {
    this.maxSize = maxSize;
    this.ttlMs = ttlMs;
    this.cache = new Map();
  }

  get(key: K): V | null {
    const entry = this.cache.get(key);
    if (!entry) return null;
    if (Date.now() - entry.ts > this.ttlMs) {
      this.cache.delete(key);
      return null;
    }
    // Move to end (most recently used)
    this.cache.delete(key);
    this.cache.set(key, entry);
    return entry.value;
  }

  set(key: K, value: V): void {
    if (this.cache.has(key)) this.cache.delete(key);
    if (this.cache.size >= this.maxSize) {
      // Delete oldest (first entry)
      const firstKey = this.cache.keys().next().value;
      if (firstKey !== undefined) this.cache.delete(firstKey);
    }
    this.cache.set(key, { value, ts: Date.now() });
  }
}

const routeCache = new LRUCache<string, RouteData>(200, 15 * 60 * 1000);

function cacheKey(oLat: number, oLng: number, dLat: number, dLng: number): string {
  return `${oLat.toFixed(3)},${oLng.toFixed(3)}->${dLat.toFixed(3)},${dLng.toFixed(3)}`;
}

// ══════════════════════════════════════════════════════════════════════
//  RATE LIMITER — IP-based, 60 requests per minute
// ══════════════════════════════════════════════════════════════════════

interface RateBucket {
  count: number;
  windowStart: number;
}

const RATE_LIMIT = 60; // requests per window
const RATE_WINDOW_MS = 60 * 1000; // 1 minute
const rateLimitMap = new Map<string, RateBucket>();

// Auto-cleanup stale entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of rateLimitMap.entries()) {
    if (now - bucket.windowStart > RATE_WINDOW_MS * 2) {
      rateLimitMap.delete(key);
    }
  }
}, 5 * 60 * 1000);

function checkRateLimit(req: Request): Response | null {
  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-real-ip") ||
    "unknown";

  const now = Date.now();
  let bucket = rateLimitMap.get(ip);

  if (!bucket || now - bucket.windowStart > RATE_WINDOW_MS) {
    bucket = { count: 1, windowStart: now };
    rateLimitMap.set(ip, bucket);
    return null; // OK
  }

  bucket.count++;

  if (bucket.count > RATE_LIMIT) {
    const retryAfterSec = Math.ceil(
      (bucket.windowStart + RATE_WINDOW_MS - now) / 1000
    );
    console.warn(`RATE_LIMIT: IP ${ip} exceeded ${RATE_LIMIT} req/min (${bucket.count})`);
    return new Response(
      JSON.stringify({
        error: "Too many requests. Please try again later.",
        retry_after_seconds: retryAfterSec,
      }),
      {
        status: 429,
        headers: {
          ...CORS,
          "Retry-After": String(retryAfterSec),
          "X-RateLimit-Limit": String(RATE_LIMIT),
          "X-RateLimit-Remaining": "0",
        },
      }
    );
  }

  return null; // OK
}

// ══════════════════════════════════════════════════════════════════════
//  MAIN HANDLER
// ══════════════════════════════════════════════════════════════════════

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // ── Rate Limit Check ──
  const rateLimitResponse = checkRateLimit(req);
  if (rateLimitResponse) return rateLimitResponse;

  const startTime = Date.now();

  try {
    const body: PricingRequest = await req.json();

    // ── VALIDATE INPUTS ──────────────────────────────────────────
    const validation = validateInputs(body);
    if (validation) return jsonResponse({ error: validation }, 400);

    const {
      origin_lat, origin_lng,
      destination_lat, destination_lng,
      parcel_size,
      travel_mode,
      time_performance = "under_time",
    } = body;

    const normalizedSize = normalizeSize(parcel_size);
    const normalizedMode = normalizeMode(travel_mode);
    const normalizedPerf = normalizePerformance(time_performance);

    // ══════════════════════════════════════════════════════════════
    //  PRIORITY 1: FLIGHT OVERRIDE
    //  If travel_mode = flight → IGNORE everything else
    // ══════════════════════════════════════════════════════════════

    if (normalizedMode === "flight") {
      const flightSize = mapToFlightSize(normalizedSize);
      const price = FLIGHT_PRICES[flightSize] ?? FLIGHT_PRICES.small;

      const response = {
        price,
        distance_km: 0,
        duration: "N/A (Flight)",
        duration_seconds: 0,
        pricing_type: "flight",
        parcel_size: flightSize,
        travel_mode: "flight",
        etr_seconds: 0,
        etr_text: "N/A",
        breakdown: {
          base_price: price,
          slab_range: "N/A",
          time_multiplier: 1.0,
          time_performance: "N/A",
          route_type: "flight",
          final_reason: `Flight override — fixed ₹${price} for ${flightSize} parcel`,
        },
      };

      await logPricing(body, response, Date.now() - startTime);
      return jsonResponse(response);
    }

    // ══════════════════════════════════════════════════════════════
    //  FETCH ROUTE DATA (Google Maps Distance Matrix + Geocoding)
    // ══════════════════════════════════════════════════════════════

    const routeData = await fetchRouteData(
      origin_lat, origin_lng, destination_lat, destination_lng
    );

    if (!routeData) {
      return jsonResponse({ error: "Unable to calculate route. Check coordinates." }, 500);
    }

    const { distance_km, duration_text, duration_seconds, origin_city, destination_city } = routeData;

    // ── COMPUTE ETR ──────────────────────────────────────────────
    // ETR = Time₁ + 10% grace
    // Time₁ = Google Maps driving time (always car mode)
    const etrSeconds = Math.ceil(duration_seconds * 1.10);
    const etrHours = Math.floor(etrSeconds / 3600);
    const etrMins = Math.floor((etrSeconds % 3600) / 60);
    const etrText = etrHours > 0 ? `${etrHours} hr ${etrMins} min` : `${etrMins} min`;

    // ── TIME MULTIPLIER ──────────────────────────────────────────
    const timeMultiplier = getTimeMultiplier(normalizedPerf);

    // ══════════════════════════════════════════════════════════════
    //  PRIORITY 2: SAME CITY FIXED PRICING
    // ══════════════════════════════════════════════════════════════

    const isSameCity = detectSameCity(distance_km, origin_city, destination_city);

    if (isSameCity) {
      const size = normalizedSize === "micro" ? "small" : normalizedSize;
      const priceKey = normalizedPerf;
      const price = SAME_CITY_PRICES[size]?.[priceKey] ?? 49;

      const response = {
        price,
        distance_km: round1(distance_km),
        duration: duration_text,
        duration_seconds,
        pricing_type: "same_city",
        parcel_size: size,
        travel_mode: normalizedMode,
        etr_seconds: etrSeconds,
        etr_text: etrText,
        breakdown: {
          base_price: 49,
          slab_range: "Same City (0–50 km)",
          time_multiplier: timeMultiplier,
          time_performance: perfLabel(normalizedPerf),
          route_type: "same_city",
          final_reason: `Same city fixed pricing — ₹${price} for ${size} parcel (${perfLabel(normalizedPerf)})`,
        },
      };

      await logPricing(body, response, Date.now() - startTime);
      return jsonResponse(response);
    }

    // ══════════════════════════════════════════════════════════════
    //  PRIORITY 3: CITY-TO-CITY SLAB PRICING
    // ══════════════════════════════════════════════════════════════

    const size = normalizedSize === "micro" ? "small" : normalizedSize;
    const slabs = getSlabsForSize(size);
    const km = Math.ceil(distance_km);
    const slab = slabs.find(s => km >= s.minKm && km <= s.maxKm);

    if (!slab) {
      // If km > 3000, use last slab
      if (km > 3000) {
        const lastSlab = slabs[slabs.length - 1];
        const price = getSlabPrice(lastSlab, normalizedPerf);

        const response = {
          price,
          distance_km: round1(distance_km),
          duration: duration_text,
          duration_seconds,
          pricing_type: "slab",
          parcel_size: size,
          travel_mode: normalizedMode,
          etr_seconds: etrSeconds,
          etr_text: etrText,
          breakdown: {
            base_price: 99,
            slab_range: `${lastSlab.minKm}–${lastSlab.maxKm} km (capped)`,
            time_multiplier: timeMultiplier,
            time_performance: perfLabel(normalizedPerf),
            route_type: "city_to_city",
            final_reason: `Distance ${km} km exceeds 3000 km, capped at max slab`,
          },
        };

        await logPricing(body, response, Date.now() - startTime);
        return jsonResponse(response);
      }

      return jsonResponse({
        error: `Distance ${distance_km.toFixed(1)} km cannot be mapped to any slab`,
      }, 400);
    }

    const price = getSlabPrice(slab, normalizedPerf);
    const slabLabel = `${slab.minKm}–${slab.maxKm} km`;

    const response = {
      price,
      distance_km: round1(distance_km),
      duration: duration_text,
      duration_seconds,
      pricing_type: "slab",
      parcel_size: size,
      travel_mode: normalizedMode,
      etr_seconds: etrSeconds,
      etr_text: etrText,
      breakdown: {
        base_price: 99,
        slab_range: slabLabel,
        time_multiplier: timeMultiplier,
        time_performance: perfLabel(normalizedPerf),
        route_type: "city_to_city",
        final_reason: `Slab ${slabLabel}, ${size} parcel, ${perfLabel(normalizedPerf)}`,
      },
    };

    await logPricing(body, response, Date.now() - startTime);
    return jsonResponse(response);

  } catch (error) {
    console.error("PRICING ENGINE FATAL:", error);
    return jsonResponse(
      { error: "Internal server error" },
      500
    );
  }
});

// ══════════════════════════════════════════════════════════════════════
//  HELPER FUNCTIONS
// ══════════════════════════════════════════════════════════════════════

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: CORS });
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

// ── INPUT VALIDATION ────────────────────────────────────────────────

function validateInputs(body: PricingRequest): string | null {
  if (!body) return "Request body is required";

  const { origin_lat, origin_lng, destination_lat, destination_lng } = body;

  if (origin_lat == null || origin_lng == null ||
      destination_lat == null || destination_lng == null) {
    return "All coordinates are required: origin_lat, origin_lng, destination_lat, destination_lng";
  }

  if (typeof origin_lat !== "number" || typeof origin_lng !== "number" ||
      typeof destination_lat !== "number" || typeof destination_lng !== "number") {
    return "All coordinates must be numbers";
  }

  if (Math.abs(origin_lat) > 90 || Math.abs(destination_lat) > 90) {
    return "Latitude must be between -90 and 90";
  }
  if (Math.abs(origin_lng) > 180 || Math.abs(destination_lng) > 180) {
    return "Longitude must be between -180 and 180";
  }

  // Check for same origin/destination
  if (origin_lat === destination_lat && origin_lng === destination_lng) {
    return "Origin and destination cannot be the same location";
  }

  return null;
}

// ── NORMALIZATION ───────────────────────────────────────────────────

function normalizeSize(size: string): string {
  const s = (size || "small").toLowerCase().trim();
  if (["small", "medium", "large", "micro"].includes(s)) return s;
  return "small";
}

function normalizeMode(mode: string): string {
  const m = (mode || "road").toLowerCase().trim();
  if (["road", "train", "bus", "flight", "bike", "car"].includes(m)) return m;
  return "road";
}

function normalizePerformance(perf: string): string {
  const p = (perf || "under_time").toLowerCase().trim();
  if (["under_time", "delay_60", "delay_above_60"].includes(p)) return p;
  return "under_time";
}

function mapToFlightSize(size: string): string {
  if (size === "large") return "medium"; // Max flight size
  if (size === "micro" || size === "small" || size === "medium") return size;
  return "small";
}

// ── TIME MULTIPLIER ─────────────────────────────────────────────────

function getTimeMultiplier(perf: string): number {
  switch (perf) {
    case "under_time": return 1.0;
    case "delay_60": return 0.85;
    case "delay_above_60": return 0.75;
    default: return 1.0;
  }
}

function perfLabel(perf: string): string {
  switch (perf) {
    case "under_time": return "Under Time (within ETR + 10%)";
    case "delay_60": return "Delay ≤60% beyond ETR";
    case "delay_above_60": return "Delay >60% beyond ETR";
    default: return "Under Time";
  }
}

// ── SLAB LOOKUP ─────────────────────────────────────────────────────

function getSlabsForSize(size: string): SlabEntry[] {
  switch (size) {
    case "small":  return [...SMALL_SLABS_1200, ...SMALL_SLABS_3000];
    case "medium": return [...MEDIUM_SLABS_1200, ...MEDIUM_SLABS_3000];
    case "large":  return [...LARGE_SLABS_1200, ...LARGE_SLABS_3000];
    default:       return [...SMALL_SLABS_1200, ...SMALL_SLABS_3000];
  }
}

function getSlabPrice(slab: SlabEntry, perf: string): number {
  switch (perf) {
    case "under_time": return slab.underTime;
    case "delay_60": return slab.delay60;
    case "delay_above_60": return slab.delayAbove60;
    default: return slab.underTime;
  }
}

// ── SAME CITY DETECTION ─────────────────────────────────────────────

function detectSameCity(distanceKm: number, originCity: string, destCity: string): boolean {
  // Method 1: Geocoding city name comparison (most accurate)
  if (originCity && destCity) {
    const normOrigin = originCity.toLowerCase().trim();
    const normDest = destCity.toLowerCase().trim();
    if (normOrigin === normDest) return true;
    if (normOrigin.includes(normDest) || normDest.includes(normOrigin)) return true;
  }

  // Method 2: Distance threshold (fallback)
  return distanceKm <= 50;
}

// ── ROUTE DATA FETCHING ─────────────────────────────────────────────

async function fetchRouteData(
  originLat: number, originLng: number,
  destLat: number, destLng: number
): Promise<RouteData | null> {
  const key = cacheKey(originLat, originLng, destLat, destLng);
  const cached = routeCache.get(key);
  if (cached) {
    console.log("📦 Cache HIT");
    return cached;
  }

  console.log("🌐 Cache MISS — fetching from Google Maps...");

  // Fetch distance + duration from Distance Matrix API (DRIVING mode always)
  let distance_km = 0;
  let duration_text = "";
  let duration_seconds = 0;

  try {
    const dmUrl = `https://maps.googleapis.com/maps/api/distancematrix/json`
      + `?origins=${originLat},${originLng}`
      + `&destinations=${destLat},${destLng}`
      + `&mode=driving`
      + `&key=${GOOGLE_MAPS_API_KEY}`;

    const dmResp = await fetch(dmUrl);
    const dmJson = await dmResp.json();

    if (dmJson.status === "OK" && dmJson.rows?.[0]?.elements?.[0]?.status === "OK") {
      const el = dmJson.rows[0].elements[0];
      distance_km = el.distance.value / 1000;
      duration_text = el.duration.text;
      duration_seconds = el.duration.value;
    } else {
      console.warn("Distance Matrix API returned non-OK:", dmJson.status);
      // Fallback to haversine
      const hav = haversineDistance(originLat, originLng, destLat, destLng);
      distance_km = hav * 1.3;
      duration_seconds = Math.round((distance_km / 50) * 3600);
      const h = Math.floor(duration_seconds / 3600);
      const m = Math.floor((duration_seconds % 3600) / 60);
      duration_text = h > 0 ? `${h} hr ${m} min` : `${m} min`;
    }
  } catch (e) {
    console.error("Distance Matrix failed:", e);
    const hav = haversineDistance(originLat, originLng, destLat, destLng);
    distance_km = hav * 1.3;
    duration_seconds = Math.round((distance_km / 50) * 3600);
    const h = Math.floor(duration_seconds / 3600);
    const m = Math.floor((duration_seconds % 3600) / 60);
    duration_text = h > 0 ? `${h} hr ${m} min` : `${m} min`;
  }

  // Fetch city names via Reverse Geocoding
  let origin_city = "";
  let destination_city = "";

  try {
    const [oc, dc] = await Promise.all([
      reverseGeocodeCity(originLat, originLng),
      reverseGeocodeCity(destLat, destLng),
    ]);
    origin_city = oc;
    destination_city = dc;
  } catch (e) {
    console.warn("Reverse geocoding failed:", e);
  }

  const result: RouteData = {
    distance_km,
    duration_text,
    duration_seconds,
    origin_city,
    destination_city,
  };

  routeCache.set(key, result);
  return result;
}

async function reverseGeocodeCity(lat: number, lng: number): Promise<string> {
  try {
    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&result_type=locality&key=${GOOGLE_MAPS_API_KEY}`;
    const resp = await fetch(url);
    const json = await resp.json();

    if (json.status === "OK" && json.results?.length > 0) {
      // Extract locality (city) from address components
      for (const component of json.results[0].address_components || []) {
        if (component.types?.includes("locality")) {
          return component.long_name;
        }
      }
      // Fallback: return formatted address
      return json.results[0].formatted_address?.split(",")[0] || "";
    }
    return "";
  } catch {
    return "";
  }
}

function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number): number {
  return deg * Math.PI / 180;
}

// ── PRICING LOG (Best effort, never blocks response) ────────────────

async function logPricing(
  request: PricingRequest,
  response: unknown,
  latencyMs: number
): Promise<void> {
  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) return;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    await supabase.from("pricing_logs").insert({
      request_payload: request,
      response_payload: response,
      latency_ms: latencyMs,
      created_at: new Date().toISOString(),
    });
  } catch (e) {
    // Best effort — never let logging fail break pricing
    console.warn("Pricing log insert failed (non-critical):", e);
  }
}
