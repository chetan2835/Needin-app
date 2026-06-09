-- 1. DROP ALL DEPENDENCIES FIRST
DROP POLICY IF EXISTS "Users can insert their own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can update their own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Anyone can view active journeys" ON public.journeys;
DROP POLICY IF EXISTS "Users can view own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Driver can update own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Driver can view own journeys" ON public.journeys;
DROP POLICY IF EXISTS "Allow journey inserts" ON public.journeys;

-- 2. DROP THE FOREIGN KEY CONSTRAINT
ALTER TABLE public.journeys DROP CONSTRAINT IF EXISTS journeys_driver_id_fkey;

-- 3. CHANGE THE COLUMN TYPE (Firebase UIDs are TEXT)
ALTER TABLE public.journeys ALTER COLUMN driver_id TYPE TEXT USING driver_id::TEXT;

-- 4. ENSURE ALL EXTENDED COLUMNS EXIST
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS acceptable_parcel_sizes TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS travel_mode TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dimensions TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS pickup_flexibility TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dropoff_flexibility TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS additional_notes TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS distance_km NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS duration_text TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS route_polyline TEXT;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS origin_lat NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS origin_lng NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dest_lat NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS dest_lng NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_small NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_medium NUMERIC;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_large NUMERIC;

-- 5. RECREATE RLS POLICIES (Using TEXT comparison)
CREATE POLICY "Anyone can view active journeys" ON public.journeys
  FOR SELECT USING (status = 'active');

CREATE POLICY "Allow journey inserts" ON public.journeys
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Driver can update own journeys" ON public.journeys
  FOR UPDATE USING (driver_id = auth.uid()::text);

CREATE POLICY "Driver can view own journeys" ON public.journeys
  FOR SELECT USING (driver_id = auth.uid()::text);

CREATE POLICY "Driver can delete own journeys" ON public.journeys
  FOR DELETE USING (driver_id = auth.uid()::text);

-- 6. RELOAD SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
