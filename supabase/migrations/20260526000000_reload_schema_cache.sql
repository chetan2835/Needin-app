-- ══════════════════════════════════════════════════════════════════════
-- CRITICAL FIX: Reload PostgREST Schema Cache
--
-- ROOT CAUSE: The production fix migration changed column types
-- (sender_id from UUID to TEXT, added new columns), but PostgREST's
-- internal schema cache still has the OLD column types cached.
--
-- When the app inserts a Firebase UID (text string like "abc123XYZ...")
-- into sender_id, PostgREST thinks it's still a UUID column and tries
-- to parse the Firebase UID as a UUID → fails with error 22P02:
--   "invalid input syntax for type uuid"
--
-- This ONE command forces PostgREST to reload its schema cache,
-- picking up the new TEXT types from the actual database columns.
--
-- Run this ONCE in Supabase Dashboard → SQL Editor → Run
-- ══════════════════════════════════════════════════════════════════════

-- Force PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';

-- Also create a helper function so the app can reload the cache
-- programmatically in the future (if needed)
CREATE OR REPLACE FUNCTION public.reload_pgrst_schema()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NOTIFY pgrst, 'reload schema';
END;
$$;

-- Grant execute to anon and authenticated roles so the app can call it
GRANT EXECUTE ON FUNCTION public.reload_pgrst_schema() TO anon;
GRANT EXECUTE ON FUNCTION public.reload_pgrst_schema() TO authenticated;

-- ── Verify the parcels schema is correct ────────────────────────────
-- These are idempotent (safe to run multiple times)

-- Ensure sender_id is TEXT (not UUID)
ALTER TABLE public.parcels DROP CONSTRAINT IF EXISTS parcels_sender_id_fkey;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parcels'
      AND column_name = 'sender_id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.parcels ALTER COLUMN sender_id TYPE TEXT USING sender_id::TEXT;
    RAISE NOTICE 'Fixed: parcels.sender_id changed from UUID to TEXT';
  ELSE
    RAISE NOTICE 'OK: parcels.sender_id is already TEXT';
  END IF;
END $$;

-- Ensure driver_id is TEXT (not UUID)
ALTER TABLE public.journeys DROP CONSTRAINT IF EXISTS journeys_driver_id_fkey;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'journeys'
      AND column_name = 'driver_id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.journeys ALTER COLUMN driver_id TYPE TEXT USING driver_id::TEXT;
    RAISE NOTICE 'Fixed: journeys.driver_id changed from UUID to TEXT';
  ELSE
    RAISE NOTICE 'OK: journeys.driver_id is already TEXT';
  END IF;
END $$;

-- Ensure profiles.id is TEXT (not UUID)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_pkey CASCADE;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.profiles ALTER COLUMN id TYPE TEXT USING id::TEXT;
    ALTER TABLE public.profiles ADD PRIMARY KEY (id);
    RAISE NOTICE 'Fixed: profiles.id changed from UUID to TEXT';
  ELSE
    RAISE NOTICE 'OK: profiles.id is already TEXT';
  END IF;
END $$;

-- Ensure required columns exist on parcels
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS traveler_id TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS parcel_size TEXT DEFAULT 'medium';
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS parcel_category TEXT;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS booking_status TEXT DEFAULT 'pending';

-- Ensure permissive RLS policies exist
DROP POLICY IF EXISTS "parcels_select_all" ON public.parcels;
CREATE POLICY "parcels_select_all" ON public.parcels FOR SELECT USING (true);

DROP POLICY IF EXISTS "parcels_insert_any" ON public.parcels;
CREATE POLICY "parcels_insert_any" ON public.parcels FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "parcels_update_any" ON public.parcels;
CREATE POLICY "parcels_update_any" ON public.parcels FOR UPDATE USING (true);

-- Final schema cache reload (after all changes)
NOTIFY pgrst, 'reload schema';
