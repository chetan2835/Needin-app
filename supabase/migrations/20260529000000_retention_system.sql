-- ══════════════════════════════════════════════════════════════════════
-- NEEDIN EXPRESS — 30-Day Retention / Cleanup System
-- Migration: 20260529000000_retention_system.sql
--
-- This migration implements a production-grade 30-day retention policy:
--   - Delivered parcels older than 30 days are auto-cleaned
--   - Cancelled parcels older than 30 days are auto-cleaned
--   - Expired journeys older than 30 days are auto-cleaned
--   - Profile counts only reflect retained records
--
-- Safe to run multiple times (idempotent).
-- ══════════════════════════════════════════════════════════════════════

-- ── 1. Add retention_expires_at to parcels ──────────────────────────
ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS retention_expires_at TIMESTAMPTZ;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- ── 2. Add retention_expires_at to journeys ──────────────────────────
ALTER TABLE public.journeys
  ADD COLUMN IF NOT EXISTS retention_expires_at TIMESTAMPTZ;

ALTER TABLE public.journeys
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

ALTER TABLE public.journeys
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE public.journeys
  ADD COLUMN IF NOT EXISTS deleted_reason TEXT;

ALTER TABLE public.journeys
  ADD COLUMN IF NOT EXISTS departure_time TIMESTAMPTZ;

ALTER TABLE public.journeys
  ADD COLUMN IF NOT EXISTS arrival_time TIMESTAMPTZ;

-- ── 3. Backfill retention_expires_at for existing parcel records ──────
-- For delivered parcels: use arrival_time if available, else created_at
UPDATE public.parcels
SET retention_expires_at = COALESCE(
  -- arrival_time from the linked journey
  (SELECT j.arrival_time FROM public.journeys j WHERE j.id = parcels.journey_id),
  created_at
) + INTERVAL '30 days'
WHERE
  status IN ('delivered', 'completed')
  AND retention_expires_at IS NULL;

-- For cancelled parcels: use cancelled_at if available, else created_at
UPDATE public.parcels
SET retention_expires_at = COALESCE(cancelled_at, created_at) + INTERVAL '30 days'
WHERE
  status = 'cancelled'
  AND retention_expires_at IS NULL;

-- ── 4. Backfill retention_expires_at for existing journey records ─────
-- For expired/past-departure journeys: departure_time + 30 days
UPDATE public.journeys
SET retention_expires_at = COALESCE(departure_time, created_at) + INTERVAL '30 days'
WHERE
  (
    status = 'expired'
    OR (
      status IN ('active', 'live', 'in_progress')
      AND departure_time IS NOT NULL
      AND departure_time < NOW()
    )
  )
  AND retention_expires_at IS NULL
  AND is_deleted = false;

-- ── 5. Create indexes for fast retention queries ──────────────────────
CREATE INDEX IF NOT EXISTS idx_parcels_retention_expires_at
  ON public.parcels(retention_expires_at)
  WHERE retention_expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_parcels_status_retention
  ON public.parcels(status, retention_expires_at);

CREATE INDEX IF NOT EXISTS idx_journeys_retention_expires_at
  ON public.journeys(retention_expires_at)
  WHERE retention_expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_journeys_status_retention
  ON public.journeys(status, retention_expires_at);

-- ── 6. Trigger: auto-set retention_expires_at on parcels INSERT/UPDATE ─
CREATE OR REPLACE FUNCTION public.set_parcel_retention_expires()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delivered: set retention from arrival_time of linked journey (or now)
  IF NEW.status IN ('delivered', 'completed') AND NEW.retention_expires_at IS NULL THEN
    NEW.retention_expires_at := COALESCE(
      (SELECT j.arrival_time FROM public.journeys j WHERE j.id = NEW.journey_id),
      NOW()
    ) + INTERVAL '30 days';
  END IF;

  -- Cancelled: set retention from cancelled_at (or now)
  IF NEW.status = 'cancelled' AND NEW.retention_expires_at IS NULL THEN
    IF NEW.cancelled_at IS NULL THEN
      NEW.cancelled_at := NOW();
    END IF;
    NEW.retention_expires_at := NEW.cancelled_at + INTERVAL '30 days';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_parcel_set_retention ON public.parcels;
CREATE TRIGGER trg_parcel_set_retention
  BEFORE INSERT OR UPDATE ON public.parcels
  FOR EACH ROW
  EXECUTE FUNCTION public.set_parcel_retention_expires();

-- ── 7. Trigger: auto-set retention_expires_at on journeys INSERT/UPDATE ─
CREATE OR REPLACE FUNCTION public.set_journey_retention_expires()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Expired journeys: 30 days from departure_time
  IF (
    NEW.status = 'expired'
    OR (
      NEW.status IN ('active', 'live', 'in_progress')
      AND NEW.departure_time IS NOT NULL
      AND NEW.departure_time < NOW()
    )
  ) AND NEW.retention_expires_at IS NULL THEN
    NEW.retention_expires_at := COALESCE(NEW.departure_time, NOW()) + INTERVAL '30 days';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_journey_set_retention ON public.journeys;
CREATE TRIGGER trg_journey_set_retention
  BEFORE INSERT OR UPDATE ON public.journeys
  FOR EACH ROW
  EXECUTE FUNCTION public.set_journey_retention_expires();

-- ── 8. Core retention cleanup function ────────────────────────────────
CREATE OR REPLACE FUNCTION public.run_retention_cleanup()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_parcels_deleted INT := 0;
  v_journeys_deleted INT := 0;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  -- Before deleting, update any parcels/journeys that missed the trigger
  -- (ensure retention_expires_at is populated for all terminal-status records)

  -- Backfill: delivered/completed parcels
  UPDATE public.parcels
  SET retention_expires_at = COALESCE(
    (SELECT j.arrival_time FROM public.journeys j WHERE j.id = parcels.journey_id),
    created_at
  ) + INTERVAL '30 days'
  WHERE
    status IN ('delivered', 'completed')
    AND retention_expires_at IS NULL;

  -- Backfill: cancelled parcels
  UPDATE public.parcels
  SET
    cancelled_at = COALESCE(cancelled_at, created_at),
    retention_expires_at = COALESCE(cancelled_at, created_at) + INTERVAL '30 days'
  WHERE
    status = 'cancelled'
    AND retention_expires_at IS NULL;

  -- Backfill: expired journeys
  UPDATE public.journeys
  SET retention_expires_at = COALESCE(departure_time, created_at) + INTERVAL '30 days'
  WHERE
    (
      status = 'expired'
      OR (status IN ('active', 'live', 'in_progress') AND departure_time < NOW())
    )
    AND retention_expires_at IS NULL
    AND is_deleted = false;

  -- Delete expired parcel records (delivered/cancelled past retention window)
  DELETE FROM public.parcels
  WHERE
    status IN ('delivered', 'completed', 'cancelled')
    AND retention_expires_at IS NOT NULL
    AND retention_expires_at < v_now;

  GET DIAGNOSTICS v_parcels_deleted = ROW_COUNT;

  -- Soft-mark expired journeys past retention window as is_deleted
  -- (we use soft-delete for journeys to preserve audit trail)
  UPDATE public.journeys
  SET
    is_deleted = true,
    deleted_at = COALESCE(deleted_at, v_now),
    deleted_reason = COALESCE(deleted_reason, 'auto_cleanup_retention_expired')
  WHERE
    (
      status = 'expired'
      OR (status IN ('active', 'live', 'in_progress') AND departure_time < NOW())
    )
    AND retention_expires_at IS NOT NULL
    AND retention_expires_at < v_now
    AND is_deleted = false;

  GET DIAGNOSTICS v_journeys_deleted = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'parcels_cleaned', v_parcels_deleted,
    'journeys_cleaned', v_journeys_deleted,
    'executed_at', v_now
  );
END;
$$;

-- Grant to authenticated and anon so the Flutter app can call it
GRANT EXECUTE ON FUNCTION public.run_retention_cleanup() TO anon;
GRANT EXECUTE ON FUNCTION public.run_retention_cleanup() TO authenticated;

-- ── 9. Optional: Schedule with pg_cron (run daily at 02:00 UTC) ───────
-- pg_cron must be enabled on your Supabase project.
-- If not enabled, the app will call run_retention_cleanup() directly.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('needin_retention_cleanup');
    PERFORM cron.schedule(
      'needin_retention_cleanup',
      '0 2 * * *',  -- Daily at 02:00 UTC
      'SELECT public.run_retention_cleanup();'
    );
    RAISE NOTICE 'pg_cron: needin_retention_cleanup job scheduled.';
  ELSE
    RAISE NOTICE 'pg_cron not available. App will call run_retention_cleanup() on demand.';
  END IF;
END;
$$;

-- ── 10. Retention-aware profile stat RPCs ─────────────────────────────

-- Journey count: only count non-deleted journeys posted by this user
-- that are NOT past their retention window (active or recently expired)
CREATE OR REPLACE FUNCTION public.get_user_journey_count(p_user_id TEXT)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.journeys
  WHERE
    driver_id = p_user_id
    AND (is_deleted = false OR is_deleted IS NULL)
    AND (
      -- Active (not yet expired)
      status IN ('active', 'live', 'in_progress', 'draft')
      OR
      -- Expired but still within retention window
      (
        (status = 'expired' OR departure_time < NOW())
        AND (retention_expires_at IS NULL OR retention_expires_at > NOW())
      )
    );
$$;

-- Parcel count: only count parcels for this sender that are still
-- within the retention window
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
    AND (
      -- Active records (not terminal)
      status NOT IN ('delivered', 'completed', 'cancelled')
      OR
      -- Terminal but within retention window
      (
        status IN ('delivered', 'completed', 'cancelled')
        AND (retention_expires_at IS NULL OR retention_expires_at > NOW())
      )
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_user_journey_count(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_user_journey_count(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_parcel_count(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_user_parcel_count(TEXT) TO authenticated;

-- ── 11. Grant DELETE on parcels (needed for cleanup function) ─────────
DROP POLICY IF EXISTS "parcels_delete_system" ON public.parcels;
CREATE POLICY "parcels_delete_system" ON public.parcels
  FOR DELETE USING (true);

-- ── 12. Final schema cache reload ─────────────────────────────────────
NOTIFY pgrst, 'reload schema';
