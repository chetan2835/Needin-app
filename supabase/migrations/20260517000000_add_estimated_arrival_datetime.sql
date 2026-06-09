-- ══════════════════════════════════════════════════════════════
-- REQUIRED: Run this migration in Supabase SQL Editor NOW
-- Adds the estimated_arrival_datetime column used by the app
-- ══════════════════════════════════════════════════════════════

-- The departure_datetime column already exists (from 20260511 lifecycle migration).
-- The estimated_arrival_datetime column needs to be added.
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS estimated_arrival_datetime TEXT;

-- Sync: populate estimated_arrival_datetime from arrival_time for existing rows
UPDATE public.journeys
SET estimated_arrival_datetime = arrival_time::TEXT
WHERE estimated_arrival_datetime IS NULL AND arrival_time IS NOT NULL;

-- Notify PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';
