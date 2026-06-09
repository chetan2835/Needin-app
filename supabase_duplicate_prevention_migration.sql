-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MIGRATION: Prevent duplicate active bookings for journeys
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- This creates a partial unique index that ensures a single journey 
-- can only have ONE active booking.
-- If someone tries to double-book (race condition or same user), 
-- PostgreSQL will reject the insert atomically.

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_booking_per_journey 
ON public.parcels (journey_id) 
WHERE status NOT IN ('cancelled', 'delivered', 'completed', 'disputed');

-- Note: To apply this to your Supabase instance, run this script 
-- in the Supabase SQL Editor.
