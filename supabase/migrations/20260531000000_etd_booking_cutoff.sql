-- ══════════════════════════════════════════════════════════════════════
-- NEEDIN EXPRESS — ETD Booking Cutoff System
-- Migration: 20260531000000_etd_booking_cutoff.sql
--
-- Enforces a strict booking cutoff at the journey's Estimated Time of
-- Departure (ETD). Once NOW() >= departure_time, no new booking can be
-- created for that journey, regardless of what the client sends.
--
-- Changes:
--   1. RPC: can_book_journey()   — checks bookability using DB server time
--   2. RPC: get_server_time()    — returns reliable NOW() for client sync
--   3. TRIGGER: check_etd_before_insert — blocks any INSERT into parcels
--              after the linked journey's departure_time has passed
--
-- Safe to run multiple times (idempotent via CREATE OR REPLACE / IF NOT EXISTS).
-- ══════════════════════════════════════════════════════════════════════

-- ── 1. RPC: can_book_journey ──────────────────────────────────────────
-- Returns {can_book: bool, reason: text, departure_time: timestamptz}
-- Uses the database's own NOW() — immune to client clock drift.

CREATE OR REPLACE FUNCTION public.can_book_journey(p_journey_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_departure_time  TIMESTAMPTZ;
  v_status          TEXT;
  v_is_deleted      BOOLEAN;
  v_now             TIMESTAMPTZ := NOW();
BEGIN
  -- Fetch the journey record
  SELECT departure_time, status, COALESCE(is_deleted, false)
  INTO   v_departure_time, v_status, v_is_deleted
  FROM   public.journeys
  WHERE  id = p_journey_id;

  -- Journey not found
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_book',       false,
      'reason',         'journey_not_found',
      'message',        'This journey no longer exists.',
      'server_time',    v_now
    );
  END IF;

  -- Soft-deleted journeys
  IF v_is_deleted THEN
    RETURN jsonb_build_object(
      'can_book',       false,
      'reason',         'journey_deleted',
      'message',        'This journey is no longer available.',
      'server_time',    v_now
    );
  END IF;

  -- Journey must be active
  IF v_status NOT IN ('active', 'live') THEN
    RETURN jsonb_build_object(
      'can_book',       false,
      'reason',         'journey_not_active',
      'message',        'This journey is not accepting new bookings.',
      'server_time',    v_now,
      'journey_status', v_status
    );
  END IF;

  -- ETD check: booking blocked at or after departure time
  IF v_departure_time IS NOT NULL AND v_now >= v_departure_time THEN
    RETURN jsonb_build_object(
      'can_book',         false,
      'reason',           'etd_passed',
      'message',          'Booking for this journey is closed because the departure time has already started.',
      'server_time',      v_now,
      'departure_time',   v_departure_time
    );
  END IF;

  -- All checks passed — booking is allowed
  RETURN jsonb_build_object(
    'can_book',         true,
    'reason',           'ok',
    'message',          'Booking is open.',
    'server_time',      v_now,
    'departure_time',   v_departure_time
  );
END;
$$;

-- Grant to authenticated users (senders calling this before booking)
GRANT EXECUTE ON FUNCTION public.can_book_journey(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_book_journey(UUID) TO anon;


-- ── 2. RPC: get_server_time ───────────────────────────────────────────
-- Returns the current DB server time as ISO 8601 string.
-- Used by the Flutter client to compare against departure_time without
-- relying solely on device time (which may be wrong).

CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT NOW();
$$;

GRANT EXECUTE ON FUNCTION public.get_server_time() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_server_time() TO anon;


-- ── 3. TRIGGER: Enforce ETD cutoff on parcel INSERT ──────────────────
-- This is the last line of defence. Even if the client bypasses all
-- frontend checks, this trigger fires BEFORE INSERT on parcels and
-- rejects the insert if the linked journey's departure_time has passed.
--
-- Error code P0001 is a generic application exception that the Flutter
-- PostgrestException handler can detect.

CREATE OR REPLACE FUNCTION public.check_etd_before_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_departure_time  TIMESTAMPTZ;
  v_is_deleted      BOOLEAN;
  v_status          TEXT;
  v_now             TIMESTAMPTZ := NOW();
BEGIN
  -- Only apply the check when a journey_id is present (linked booking)
  IF NEW.journey_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Fetch departure time and journey state
  SELECT departure_time, COALESCE(is_deleted, false), status
  INTO   v_departure_time, v_is_deleted, v_status
  FROM   public.journeys
  WHERE  id = NEW.journey_id;

  -- Journey must exist
  IF NOT FOUND THEN
    RAISE EXCEPTION
      USING MESSAGE = 'ETD_BOOKING_CUTOFF: Journey not found. Cannot create booking.',
            ERRCODE = 'P0001';
  END IF;

  -- Journey must not be deleted
  IF v_is_deleted THEN
    RAISE EXCEPTION
      USING MESSAGE = 'ETD_BOOKING_CUTOFF: This journey is no longer available.',
            ERRCODE = 'P0001';
  END IF;

  -- ETD cutoff: reject insert if NOW() >= departure_time
  IF v_departure_time IS NOT NULL AND v_now >= v_departure_time THEN
    RAISE EXCEPTION
      USING MESSAGE = 'ETD_BOOKING_CUTOFF: Booking is closed. The departure time for this journey has already passed.',
            HINT    = 'departure_time=' || v_departure_time::TEXT || ' server_now=' || v_now::TEXT,
            ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

-- Drop and recreate trigger (idempotent)
DROP TRIGGER IF EXISTS trg_check_etd_before_booking ON public.parcels;
CREATE TRIGGER trg_check_etd_before_booking
  BEFORE INSERT ON public.parcels
  FOR EACH ROW
  EXECUTE FUNCTION public.check_etd_before_booking();


-- ── 4. Index: fast ETD lookup on journeys.departure_time ─────────────
-- Ensures the trigger and RPC resolve departure_time quickly at scale.
CREATE INDEX IF NOT EXISTS idx_journeys_departure_time
  ON public.journeys(departure_time)
  WHERE departure_time IS NOT NULL AND is_deleted = false;


-- ── 5. Reload PostgREST schema cache ─────────────────────────────────
NOTIFY pgrst, 'reload schema';
