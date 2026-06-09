-- ======================================================================
-- Needin Express: Profile + Journey Schema Hardening
-- Created: 2026-05-13
-- ======================================================================

-- ─── 1. Profile Table: Identity Verification & Email Columns ─────────
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS is_profile_complete BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS identity_verification_status TEXT DEFAULT 'pending'
    CHECK (identity_verification_status IN ('pending', 'skipped', 'verified', 'rejected'));

-- Update existing profiles to mark complete where required fields exist
UPDATE profiles 
SET is_profile_complete = TRUE
WHERE full_name IS NOT NULL 
  AND full_name != '' 
  AND city IS NOT NULL 
  AND city != '';

-- ─── 2. Journey Table: Mode-Aware Duration Metadata ──────────────────
ALTER TABLE journeys
  ADD COLUMN IF NOT EXISTS route_calculation_source TEXT DEFAULT 'driving',
  ADD COLUMN IF NOT EXISTS calculation_timestamp TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS route_duration_hours INTEGER;

-- ─── 3. RLS: Ensure profiles can be updated by owner ─────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname = 'profiles_update_own'
  ) THEN
    CREATE POLICY profiles_update_own ON profiles
      FOR UPDATE USING (auth.uid()::text = id);
  END IF;
END $$;

-- ─── 4. Index for journey arrival time queries ───────────────────────
CREATE INDEX IF NOT EXISTS idx_journeys_arrival 
  ON journeys (arrival_time, travel_mode);
