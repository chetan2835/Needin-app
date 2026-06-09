-- ══════════════════════════════════════════════════════════════════════
-- COMPREHENSIVE SCHEMA FIX: Run this ONCE in Supabase SQL Editor
-- This migration adds ALL columns the app needs, idempotently.
-- Safe to run multiple times (uses IF NOT EXISTS everywhere).
-- ══════════════════════════════════════════════════════════════════════

-- ─── 1. Journey extended columns ────────────────────────────────────
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
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
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS driver_name TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS driver_rating TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS driver_avatar_url TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS deleted_reason TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS has_bookings BOOLEAN DEFAULT FALSE;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS is_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS expired_at TIMESTAMP WITH TIME ZONE;

-- Backfill is_deleted
UPDATE public.journeys SET is_deleted = FALSE WHERE is_deleted IS NULL;

-- ─── 2. Fix driver_id type (Firebase UID = text, not UUID) ─────────
-- Drop FK constraint first if it exists
ALTER TABLE public.journeys DROP CONSTRAINT IF EXISTS journeys_driver_id_fkey;
-- Change type (safe even if already TEXT)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'journeys'
      AND column_name = 'driver_id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.journeys ALTER COLUMN driver_id TYPE TEXT USING driver_id::TEXT;
  END IF;
END $$;

-- ─── 3. Fix status constraint ──────────────────────────────────────
ALTER TABLE public.journeys DROP CONSTRAINT IF EXISTS journeys_status_check;
ALTER TABLE public.journeys ADD CONSTRAINT journeys_status_check
  CHECK (status IN ('draft', 'active', 'completed', 'cancelled', 'expired'));

-- ─── 4. Fix parcels table ──────────────────────────────────────────
-- Drop FK and fix sender_id type
ALTER TABLE public.parcels DROP CONSTRAINT IF EXISTS parcels_sender_id_fkey;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parcels'
      AND column_name = 'sender_id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.parcels ALTER COLUMN sender_id TYPE TEXT USING sender_id::TEXT;
  END IF;
END $$;

-- Allow nullable journey_id for unmatched bookings
ALTER TABLE public.parcels DROP CONSTRAINT IF EXISTS parcels_journey_id_fkey;
ALTER TABLE public.parcels ALTER COLUMN journey_id DROP NOT NULL;

-- Add booking/audit columns
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS traveler_id TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS parcel_size TEXT DEFAULT 'medium';
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS parcel_category TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS booking_status TEXT DEFAULT 'pending';
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS cancelled_by TEXT;

-- ─── 5. Notifications table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  type text DEFAULT 'info',
  is_read boolean DEFAULT FALSE,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ─── 6. Drop ALL existing RLS policies (safe if they don't exist) ──
-- Journeys
DROP POLICY IF EXISTS "Anyone can view active journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can view own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can insert their own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can update their own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can delete their own journeys" ON public.journeys;
DROP POLICY IF EXISTS "journeys_select_own" ON public.journeys;
DROP POLICY IF EXISTS "journeys_select_active" ON public.journeys;
DROP POLICY IF EXISTS "journeys_insert_own" ON public.journeys;
DROP POLICY IF EXISTS "journeys_update_own" ON public.journeys;
DROP POLICY IF EXISTS "journeys_delete_own" ON public.journeys;
DROP POLICY IF EXISTS "journeys_select_own_or_active" ON public.journeys;
DROP POLICY IF EXISTS "Allow journey inserts" ON public.journeys;
DROP POLICY IF EXISTS "Driver can update own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Driver can view own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Driver can delete own journeys" ON public.journeys;
DROP POLICY IF EXISTS "journeys_select_all" ON public.journeys;
DROP POLICY IF EXISTS "journeys_insert_any" ON public.journeys;
DROP POLICY IF EXISTS "journeys_update_any" ON public.journeys;
DROP POLICY IF EXISTS "journeys_delete_any" ON public.journeys;
-- Parcels
DROP POLICY IF EXISTS "Users can insert parcels" ON public.parcels;
DROP POLICY IF EXISTS "Users can view own parcels" ON public.parcels;
DROP POLICY IF EXISTS "Users can update own parcels" ON public.parcels;
DROP POLICY IF EXISTS "parcels_insert_own" ON public.parcels;
DROP POLICY IF EXISTS "parcels_select_own" ON public.parcels;
DROP POLICY IF EXISTS "parcels_update_own" ON public.parcels;
DROP POLICY IF EXISTS "parcels_select_all" ON public.parcels;
DROP POLICY IF EXISTS "parcels_insert_any" ON public.parcels;
DROP POLICY IF EXISTS "parcels_update_any" ON public.parcels;
-- Notifications
DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select_all" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_any" ON public.notifications;

-- ─── 7. Create NEW permissive RLS policies ─────────────────────────
-- Firebase Auth = no Supabase auth.uid() → permissive policies
CREATE POLICY "journeys_select_all" ON public.journeys FOR SELECT USING (true);
CREATE POLICY "journeys_insert_any" ON public.journeys FOR INSERT WITH CHECK (true);
CREATE POLICY "journeys_update_any" ON public.journeys FOR UPDATE USING (true);
CREATE POLICY "journeys_delete_any" ON public.journeys FOR DELETE USING (true);

CREATE POLICY "parcels_select_all" ON public.parcels FOR SELECT USING (true);
CREATE POLICY "parcels_insert_any" ON public.parcels FOR INSERT WITH CHECK (true);
CREATE POLICY "parcels_update_any" ON public.parcels FOR UPDATE USING (true);

CREATE POLICY "notifications_select_all" ON public.notifications FOR SELECT USING (true);
CREATE POLICY "notifications_insert_any" ON public.notifications FOR INSERT WITH CHECK (true);

-- ─── 8. Performance indexes ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_journeys_driver_id ON public.journeys (driver_id);
CREATE INDEX IF NOT EXISTS idx_journeys_status ON public.journeys (status);
CREATE INDEX IF NOT EXISTS idx_journeys_is_deleted ON public.journeys (is_deleted);
CREATE INDEX IF NOT EXISTS idx_parcels_sender_id ON public.parcels (sender_id);
CREATE INDEX IF NOT EXISTS idx_parcels_traveler_id ON public.parcels (traveler_id);

-- ─── 9. Reload PostgREST schema cache ──────────────────────────────
NOTIFY pgrst, 'reload schema';
