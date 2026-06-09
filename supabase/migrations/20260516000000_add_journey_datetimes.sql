-- Migration: Add explicit datetime columns to preserve user-selected timestamps
-- This ensures no timezone conversion shifts the displayed values
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS departure_datetime TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS estimated_arrival_datetime TEXT;
NOTIFY pgrst, 'reload schema';
