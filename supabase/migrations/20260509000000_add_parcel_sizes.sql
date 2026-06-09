-- ══════════════════════════════════════════════════════════════
-- Migration: Add all extended journey columns to journeys table
-- Run this ONCE in Supabase SQL Editor → then click "Run"
-- ══════════════════════════════════════════════════════════════

-- Core columns that the Flutter app sends
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS acceptable_parcel_sizes TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS travel_mode TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dimensions TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS pickup_flexibility TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dropoff_flexibility TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS additional_notes TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS distance_km NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS duration_text TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS route_polyline TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS origin_lat NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS origin_lng NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dest_lat NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dest_lng NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_small NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_medium NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_large NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS driver_name TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS driver_rating TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS driver_avatar_url TEXT;

-- Allow users to see their OWN journeys regardless of status (for My Journeys tab)
DROP POLICY IF EXISTS "Users can view own journeys" ON public.journeys;
CREATE POLICY "Users can view own journeys" ON public.journeys
  FOR SELECT USING (auth.uid()::text = user_id OR auth.uid() = driver_id);

-- Notify PostgREST to reload its schema cache IMMEDIATELY
-- (no server restart needed)
NOTIFY pgrst, 'reload schema';
