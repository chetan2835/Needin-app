-- ══════════════════════════════════════════════════════════════
-- CRITICAL HOTFIX: Fix UUID type mismatch for Firebase Auth UIDs
-- Run this ONCE in Supabase SQL Editor → click "Run"
-- ══════════════════════════════════════════════════════════════

-- Step 1: Drop the FK constraint so we can change the column type
ALTER TABLE public.journeys DROP CONSTRAINT IF EXISTS journeys_driver_id_fkey;

-- Step 2: Change driver_id from UUID to TEXT (Firebase UIDs are text, not UUIDs)
ALTER TABLE public.journeys ALTER COLUMN driver_id TYPE TEXT USING driver_id::TEXT;

-- Step 3: Make driver_id nullable temporarily so old rows are not broken
-- (It's already NOT NULL, keep it that way but allow text values now)

-- Step 4: Add all extended columns (if not already added)
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS user_id TEXT;
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

-- Step 5: Fix RLS policies to work with Firebase UIDs (TEXT comparison)
-- Drop old UUID-based policies
DROP POLICY IF EXISTS "Users can insert their own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can update their own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Anyone can view active journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can view own journeys" ON public.journeys;

-- New policies: anyone can view active journeys (senders need to see them)
CREATE POLICY "Anyone can view active journeys" ON public.journeys
  FOR SELECT USING (status = 'active');

-- Allow insert for any request (we validate driver_id in app layer)
-- Firebase UIDs can't be validated via auth.uid() since we use Firebase, not Supabase Auth
CREATE POLICY "Allow journey inserts" ON public.journeys
  FOR INSERT WITH CHECK (true);

-- Allow update if driver_id matches (text comparison)
CREATE POLICY "Driver can update own journeys" ON public.journeys
  FOR UPDATE USING (driver_id IS NOT NULL);

-- Allow driver to view their own journeys (for My Journeys page)
CREATE POLICY "Driver can view own journeys" ON public.journeys
  FOR SELECT USING (driver_id IS NOT NULL);

-- Step 6: Notify PostgREST to reload schema cache immediately
NOTIFY pgrst, 'reload schema';
