// @ts-nocheck
// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — Pricing Edge Function v4.0
//  Same City: ≤15 km | Delay tiers: 30% | Flight: s=449/m=649/l=949
// ══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GOOGLE_MAPS_API_KEY = Deno.env.get("GOOGLE_MAPS_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const SAME_CITY_THRESHOLD_KM = 15;
const MAX_DISTANCE_KM = 3000;
const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Content-Type": "application/json" };

// ── TYPES ──
interface SlabEntry { minKm: number; maxKm: number; underTime: number; delay30: number; delayAbove30: number; }
interface RouteData { distance_km: number; duration_text: string; duration_seconds: number; origin_city: string; destination_city: string; }

// ── SAME CITY PRICES ──
const SAME_CITY: Record<string, Record<string, number>> = {
  small:  { under_time: 49, delay_30: 49, delay_above_30: 49 },
  medium: { under_time: 79, delay_30: 69, delay_above_30: 59 },
  large:  { under_time: 99, delay_30: 89, delay_above_30: 79 },
};

// ── FLIGHT PRICES ──
const FLIGHT: Record<string, number> = { small: 449, medium: 649, large: 949 };

// ── SLAB DATA ──
const S = (min: number, max: number, u: number, d: number, a: number): SlabEntry => ({ minKm: min, maxKm: max, underTime: u, delay30: d, delayAbove30: a });

const SMALL_1200: SlabEntry[] = [S(1,100,99,89,79),S(101,200,129,109,99),S(201,300,159,139,119),S(301,400,189,159,139),S(401,500,219,189,169),S(501,600,249,209,189),S(601,700,279,239,209),S(701,800,309,259,229),S(801,900,339,289,259),S(901,1000,369,319,279),S(1001,1100,399,339,299),S(1101,1200,429,369,319)];
const SMALL_3000: SlabEntry[] = [S(1201,1300,449,379,339),S(1301,1400,469,399,349),S(1401,1500,489,419,369),S(1501,1600,509,429,379),S(1601,1700,529,449,399),S(1701,1800,549,469,409),S(1801,1900,569,479,429),S(1901,2000,589,499,439),S(2001,2100,609,519,459),S(2101,2200,629,529,469),S(2201,2300,649,549,489),S(2301,2400,669,569,499),S(2401,2500,689,579,519),S(2501,2600,709,599,529),S(2601,2700,729,619,549),S(2701,2800,749,629,559),S(2801,2900,769,649,579),S(2901,3000,789,669,589)];
const MED_1200: SlabEntry[] = [S(1,100,149,129,109),S(101,200,189,159,139),S(201,300,239,209,179),S(301,400,279,239,209),S(401,500,329,279,249),S(501,600,369,319,279),S(601,700,419,359,319),S(701,800,459,389,349),S(801,900,509,429,379),S(901,1000,549,469,409),S(1001,1100,599,509,449),S(1101,1200,639,539,479)];
const MED_3000: SlabEntry[] = [S(1201,1300,669,569,499),S(1301,1400,699,589,519),S(1401,1500,729,619,549),S(1501,1600,759,649,569),S(1601,1700,789,669,589),S(1701,1800,819,699,609),S(1801,1900,849,719,629),S(1901,2000,879,749,659),S(2001,2100,909,769,679),S(2101,2200,939,799,699),S(2201,2300,969,819,719),S(2301,2400,999,849,749),S(2401,2500,1029,869,769),S(2501,2600,1059,899,789),S(2601,2700,1089,919,819),S(2701,2800,1119,949,839),S(2801,2900,1149,969,869),S(2901,3000,1179,999,889)];
const LRG_1200: SlabEntry[] = [S(1,100,199,169,149),S(101,200,259,219,199),S(201,300,319,269,239),S(301,400,379,319,279),S(401,500,439,369,319),S(501,600,499,419,369),S(601,700,559,469,409),S(701,800,619,519,459),S(801,900,679,569,499),S(901,1000,739,619,549),S(1001,1100,799,669,599),S(1101,1200,859,719,639)];
const LRG_3000: SlabEntry[] = [S(1201,1300,899,759,679),S(1301,1400,939,799,699),S(1401,1500,979,829,739),S(1501,1600,1019,869,759),S(1601,1700,1059,899,789),S(1701,1800,1099,939,819),S(1801,1900,1139,969,849),S(1901,2000,1179,999,879),S(2001,2100,1219,1039,919),S(2101,2200,1259,1069,949),S(2201,2300,1299,1109,979),S(2301,2400,1339,1139,1009),S(2401,2500,1379,1169,1039),S(2501,2600,1419,1209,1069),S(2601,2700,1459,1239,1109),S(2701,2800,1499,1279,1139),S(2801,2900,1539,1309,1169),S(2901,3000,1579,1349,1189)];

function getSlabs(size: string): SlabEntry[] {
  if (size === "medium") return [...MED_1200, ...MED_3000];
  if (size === "large") return [...LRG_1200, ...LRG_3000];
  return [...SMALL_1200, ...SMALL_3000];
}

function findSlab(slabs: SlabEntry[], km: number): SlabEntry | null {
  for (const s of slabs) { if (km >= s.minKm && km <= s.maxKm) return s; }
  return null;
}

function getSlabPrice(slab: SlabEntry, perf: string): number {
  if (perf === "delay_30") return slab.delay30;
  if (perf === "delay_above_30") return slab.delayAbove30;
  return slab.underTime;
}

function normalizeSize(s: string): string { const v = (s||"small").toLowerCase().trim(); return ["small","medium","large"].includes(v)?v:"small"; }
function normalizeMode(m: string): string { const v = (m||"road").toLowerCase().trim(); return ["road","train","bus","flight","bike","car"].includes(v)?v:"road"; }
function normalizePerf(p: string): string { const v = (p||"under_time").toLowerCase().trim(); return ["under_time","delay_30","delay_above_30"].includes(v)?v:"under_time"; }

function perfLabel(p: string): string {
  if (p === "delay_30") return "Delay ≤30% beyond ETR";
  if (p === "delay_above_30") return "Delay >30% beyond ETR";
  return "Under Time (within ETR + 10%)";
}

const routeCache = new Map<string, RouteData>();
function cacheKey(a: number, b: number, c: number, d: number): string { return `${a.toFixed(3)},${b.toFixed(3)}->${c.toFixed(3)},${d.toFixed(3)}`; }

function haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371, dLat = (lat2-lat1)*Math.PI/180, dLon = (lon2-lon1)*Math.PI/180;
  const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180)*Math.cos(lat2*Math.PI/180)*Math.sin(dLon/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

async function fetchRoute(oLat: number, oLng: number, dLat: number, dLng: number): Promise<RouteData> {
  const key = cacheKey(oLat, oLng, dLat, dLng);
  const cached = routeCache.get(key);
  if (cached) return cached;

  let distance_km = 0, duration_text = "", duration_seconds = 0;
  try {
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${oLat},${oLng}&destinations=${dLat},${dLng}&mode=driving&key=${GOOGLE_MAPS_API_KEY}`;
    const r = await fetch(url);
    const j = await r.json();
    if (j.status === "OK" && j.rows?.[0]?.elements?.[0]?.status === "OK") {
      const el = j.rows[0].elements[0];
      distance_km = el.distance.value / 1000;
      duration_text = el.duration.text;
      duration_seconds = el.duration.value;
    } else { throw new Error("non-OK"); }
  } catch {
    const hav = haversine(oLat, oLng, dLat, dLng) * 1.3;
    distance_km = hav; duration_seconds = Math.round((hav/50)*3600);
    const h = Math.floor(duration_seconds/3600), m = Math.floor((duration_seconds%3600)/60);
    duration_text = h > 0 ? `${h} hr ${m} min` : `${m} min`;
  }

  let origin_city = "", destination_city = "";
  try {
    const gc = async (lat: number, lng: number) => {
      const r = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&result_type=locality&key=${GOOGLE_MAPS_API_KEY}`);
      const j = await r.json();
      if (j.status === "OK" && j.results?.length > 0) {
        for (const c of j.results[0].address_components || []) { if (c.types?.includes("locality")) return c.long_name; }
        return j.results[0].formatted_address?.split(",")[0] || "";
      }
      return "";
    };
    [origin_city, destination_city] = await Promise.all([gc(oLat, oLng), gc(dLat, dLng)]);
  } catch { /* non-critical */ }

  const result: RouteData = { distance_km, duration_text, duration_seconds, origin_city, destination_city };
  routeCache.set(key, result);
  return result;
}

async function logPricing(req: unknown, res: unknown, ms: number) {
  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) return;
    const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    await sb.from("pricing_logs").insert({ request_payload: req, response_payload: res, latency_ms: ms, created_at: new Date().toISOString() });
  } catch { /* best effort */ }
}

// ── MAIN HANDLER ──
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const t0 = Date.now();
  try {
    const body = await req.json();
    const { origin_lat, origin_lng, destination_lat, destination_lng } = body;
    const parcelSize = normalizeSize(body.parcel_size);
    const travelMode = normalizeMode(body.travel_mode);
    const timePerf = normalizePerf(body.time_performance);

    // ═══ FLIGHT ═══
    if (travelMode === "flight") {
      const price = FLIGHT[parcelSize] || 449;
      const res = { price, distance_km: 0, duration: "N/A", pricing_type: "flight", parcel_size: parcelSize, travel_mode: "flight", etr_seconds: 0, etr_text: "N/A",
        breakdown: { base_price: price, slab_range: "N/A", time_multiplier: 1.0, time_performance: "N/A", route_type: "flight", final_reason: `Flight fixed fare — ₹${price} for ${parcelSize} parcel`, flight_category: parcelSize } };
      logPricing(body, res, Date.now()-t0);
      return new Response(JSON.stringify(res), { headers: CORS });
    }

    // ═══ FETCH ROUTE ═══
    const route = await fetchRoute(origin_lat, origin_lng, destination_lat, destination_lng);
    const distKm = route.distance_km;
    const etrSeconds = Math.ceil(route.duration_seconds * 1.1);
    const etrH = Math.floor(etrSeconds/3600), etrM = Math.floor((etrSeconds%3600)/60);
    const etrText = etrH > 0 ? `${etrH} hr ${etrM} min` : `${etrM} min`;

    // ═══ MAX DISTANCE CHECK ═══
    if (distKm > MAX_DISTANCE_KM) {
      return new Response(JSON.stringify({ error: `Route distance ${distKm.toFixed(1)} km exceeds maximum ${MAX_DISTANCE_KM} km` }), { status: 400, headers: CORS });
    }

    // ═══ SAME CITY ═══
    const isSameCity = distKm <= SAME_CITY_THRESHOLD_KM;
    if (isSameCity) {
      const perfKey = timePerf === "delay_30" ? "delay_30" : timePerf === "delay_above_30" ? "delay_above_30" : "under_time";
      const price = SAME_CITY[parcelSize]?.[perfKey] ?? 49;
      const res = { price, distance_km: Math.round(distKm*10)/10, duration: route.duration_text, pricing_type: "same_city", parcel_size: parcelSize, travel_mode: travelMode, etr_seconds: etrSeconds, etr_text: etrText,
        breakdown: { base_price: 49, slab_range: `Same City (≤${SAME_CITY_THRESHOLD_KM} km)`, time_multiplier: timePerf==="delay_30"?0.85:timePerf==="delay_above_30"?0.75:1.0, time_performance: perfLabel(timePerf), route_type: "same_city", final_reason: `Same city — ₹${price} for ${parcelSize} (${perfLabel(timePerf)})` } };
      logPricing(body, res, Date.now()-t0);
      return new Response(JSON.stringify(res), { headers: CORS });
    }

    // ═══ CITY-TO-CITY SLAB ═══
    const km = Math.ceil(distKm);
    const slabs = getSlabs(parcelSize);
    const slab = findSlab(slabs, km);
    if (!slab) {
      return new Response(JSON.stringify({ error: `No slab found for ${distKm.toFixed(1)} km` }), { status: 400, headers: CORS });
    }

    const price = getSlabPrice(slab, timePerf);
    const slabLabel = `${slab.minKm}–${slab.maxKm} km`;
    const timeMult = timePerf==="delay_30"?0.85:timePerf==="delay_above_30"?0.75:1.0;
    const res = { price, distance_km: Math.round(distKm*10)/10, duration: route.duration_text, pricing_type: "slab", parcel_size: parcelSize, travel_mode: travelMode, etr_seconds: etrSeconds, etr_text: etrText,
      breakdown: { base_price: 99, slab_range: slabLabel, time_multiplier: timeMult, time_performance: perfLabel(timePerf), route_type: "city_to_city", final_reason: `Slab ${slabLabel}, ${parcelSize} parcel, ${perfLabel(timePerf)}` } };
    logPricing(body, res, Date.now()-t0);
    return new Response(JSON.stringify(res), { headers: CORS });

  } catch (e) {
    return new Response(JSON.stringify({ error: `Pricing calculation failed: ${e.message}` }), { status: 500, headers: CORS });
  }
});
