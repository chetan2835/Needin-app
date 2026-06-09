-- Add new columns to journeys for lifecycle and drafts
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS departure_datetime timestamp with time zone;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS has_bookings boolean DEFAULT false;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS is_completed boolean DEFAULT false;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS expired_at timestamp with time zone;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS draft_data jsonb;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS current_step integer;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS completion_percentage integer;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS last_saved_at timestamp with time zone;

-- Update status constraint to include 'expired'
ALTER TABLE public.journeys DROP CONSTRAINT IF EXISTS journeys_status_check;
ALTER TABLE public.journeys ADD CONSTRAINT journeys_status_check CHECK (status IN ('draft', 'active', 'completed', 'cancelled', 'expired'));

-- Sync departure_datetime with existing departure_time if null
UPDATE public.journeys SET departure_datetime = departure_time WHERE departure_datetime IS NULL;

-- Create pg_cron extension if not exists
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a function to expire journeys
CREATE OR REPLACE FUNCTION expire_past_journeys()
RETURNS void AS $$
BEGIN
  -- Move to completed if it has bookings
  UPDATE public.journeys
  SET status = 'completed', is_completed = true
  WHERE status = 'active'
    AND departure_datetime < NOW()
    AND has_bookings = true;

  -- Move to expired if no bookings
  UPDATE public.journeys
  SET status = 'expired', expired_at = NOW()
  WHERE status = 'active'
    AND departure_datetime < NOW()
    AND has_bookings = false;
END;
$$ LANGUAGE plpgsql;

-- Schedule the job to run every minute
-- (Depending on Supabase environment, pg_cron might need to be enabled in dashboard first)
-- We'll try to schedule it, but wrap it to not fail if pg_cron is unavailable
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule('expire_journeys_job', '* * * * *', 'SELECT expire_past_journeys()');
  END IF;
END $$;
