-- ══════════════════════════════════════════════════════════════════════
-- NEEDIN EXPRESS — Cancellation-Aware Parcel Count Fix
-- Migration: 20260601000000_fix_cancelled_parcel_count.sql
--
-- ROOT CAUSE:
--   The get_user_parcel_count function defined in 20260529000000_retention_system.sql
--   included cancelled parcels within the 30-day retention window in the count.
--   A freshly-cancelled booking was still reflected in the Profile Parcels stat.
--
-- FIX:
--   Redefine get_user_parcel_count to ALWAYS exclude cancelled and disputed
--   bookings from the profile parcel count regardless of retention window.
--   Only active and terminal-but-retained (delivered/completed) parcels count.
--
-- BUSINESS RULE:
--   cancelled → NEVER counted
--   disputed  → NEVER counted
--   active/pending/confirmed/in_transit/draft → COUNTED
--   delivered/completed within 30d retention  → COUNTED
--   delivered/completed past 30d retention    → NOT COUNTED (already cleaned)
--
-- Safe to run multiple times (idempotent via CREATE OR REPLACE).
-- ══════════════════════════════════════════════════════════════════════

-- ── Core Fix: Redefine get_user_parcel_count ─────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_parcel_count(p_user_id TEXT)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.parcels
  WHERE
    sender_id = p_user_id
    -- Critical: cancelled and disputed are NEVER counted regardless of
    -- retention window. This is the core fix for the profile count bug.
    AND status NOT IN ('cancelled', 'disputed')
    AND (
      -- Active records (not yet terminal) — always count
      status NOT IN ('delivered', 'completed')
      OR
      -- Terminal (delivered/completed) only within 30-day retention window
      (
        status IN ('delivered', 'completed')
        AND (retention_expires_at IS NULL OR retention_expires_at > NOW())
      )
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_user_parcel_count(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_user_parcel_count(TEXT) TO authenticated;

-- ── Performance: index to speed up the profile stat query ────────────
CREATE INDEX IF NOT EXISTS idx_parcels_sender_status_retention
  ON public.parcels(sender_id, status, retention_expires_at);

-- ── Force PostgREST schema cache reload ──────────────────────────────
NOTIFY pgrst, 'reload schema';
