-- ══════════════════════════════════════════════════════════════════════
-- PRODUCTION FIX MIGRATION: 20260520000000
-- ROOT CAUSE: App uses Firebase Auth (text UIDs), NOT Supabase Auth.
--   - driver_id was changed to TEXT in 20260509000001
--   - sender_id in parcels is still UUID — must also be changed to TEXT
--   - auth.uid() is INVALID because there is no Supabase Auth session
--   - RLS must use permissive policies (WITH CHECK true) since we can't
--     validate Firebase UIDs via auth.uid()
-- Run this ONCE in Supabase SQL Editor → Run
-- ══════════════════════════════════════════════════════════════════════

-- ─── 1. Ensure is_deleted column on journeys ─────────────────────────
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
UPDATE public.journeys SET is_deleted = FALSE WHERE is_deleted IS NULL;

-- ─── 1.5 Drop ALL existing parcel RLS policies BEFORE altering columns
DROP POLICY IF EXISTS "Users can insert parcels" ON public.parcels;
DROP POLICY IF EXISTS "Users can view own parcels" ON public.parcels;
DROP POLICY IF EXISTS "Users can update own parcels" ON public.parcels;
DROP POLICY IF EXISTS "parcels_insert_own" ON public.parcels;
DROP POLICY IF EXISTS "parcels_select_own" ON public.parcels;
DROP POLICY IF EXISTS "parcels_update_own" ON public.parcels;

-- ─── 2. Fix parcels table: change sender_id from UUID to TEXT ────────
-- Drop FK constraint first
ALTER TABLE public.parcels DROP CONSTRAINT IF EXISTS parcels_sender_id_fkey;
-- Change type
ALTER TABLE public.parcels ALTER COLUMN sender_id TYPE TEXT USING sender_id::TEXT;
-- Drop NOT NULL temporarily to allow the type change
ALTER TABLE public.parcels ALTER COLUMN sender_id SET NOT NULL;

-- Fix journey_id to TEXT too (journeys.id is UUID but we store text IDs)
ALTER TABLE public.parcels DROP CONSTRAINT IF EXISTS parcels_journey_id_fkey;
-- journey_id stays as UUID since journeys.id is UUID (auto-generated)
-- But we need to allow NULL for bookings not yet matched
ALTER TABLE public.parcels ALTER COLUMN journey_id DROP NOT NULL;

-- Add missing columns for booking enrichment and auditing
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS traveler_id TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS parcel_size TEXT DEFAULT 'medium';
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS parcel_category TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS booking_status TEXT DEFAULT 'pending';
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS cancelled_by TEXT;

ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS deleted_reason TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- ─── 3. Fix notifications table ──────────────────────────────────────
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

-- ─── 4. Drop ALL existing journey RLS policies ──────────────────────
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

-- ─── 5. Create NEW journey RLS policies ─────────────────────────────
-- Since we use Firebase Auth (not Supabase Auth), auth.uid() won't work.
-- We use permissive policies and validate ownership in the app layer.

-- SELECT: Anyone can read journeys (needed for traveler discovery + own journeys)
CREATE POLICY "journeys_select_all" ON public.journeys
  FOR SELECT USING (true);

-- INSERT: Allow all authenticated inserts (Firebase UID validated in app)
CREATE POLICY "journeys_insert_any" ON public.journeys
  FOR INSERT WITH CHECK (true);

-- UPDATE: Allow updates (app validates ownership via driver_id match)
CREATE POLICY "journeys_update_any" ON public.journeys
  FOR UPDATE USING (true);

-- DELETE: Allow deletes (app validates ownership)
CREATE POLICY "journeys_delete_any" ON public.journeys
  FOR DELETE USING (true);

-- ─── 6. Create NEW parcel RLS policies ──────────────────────────────
CREATE POLICY "parcels_select_all" ON public.parcels
  FOR SELECT USING (true);

CREATE POLICY "parcels_insert_any" ON public.parcels
  FOR INSERT WITH CHECK (true);

CREATE POLICY "parcels_update_any" ON public.parcels
  FOR UPDATE USING (true);

-- ─── 7. Notification RLS ────────────────────────────────────────────
DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_own" ON public.notifications;

CREATE POLICY "notifications_select_all" ON public.notifications
  FOR SELECT USING (true);

CREATE POLICY "notifications_insert_any" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- ─── 8. Indexes for performance ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_journeys_driver_id ON public.journeys (driver_id);
CREATE INDEX IF NOT EXISTS idx_journeys_status ON public.journeys (status);
CREATE INDEX IF NOT EXISTS idx_journeys_is_deleted ON public.journeys (is_deleted);
CREATE INDEX IF NOT EXISTS idx_parcels_sender_id ON public.parcels (sender_id);
CREATE INDEX IF NOT EXISTS idx_parcels_traveler_id ON public.parcels (traveler_id);

-- ─── 9. Reload PostgREST schema cache ──────────────────────────────
NOTIFY pgrst, 'reload schema';
