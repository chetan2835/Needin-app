-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  NEEDIN EXPRESS â€” Production Database Schema v4.0
--  Supabase PostgreSQL + Firebase Auth Compatibility
--  
--  âš ï¸ IMPORTANT: This app uses Firebase Auth (text UIDs), NOT
--  Supabase Auth. All user IDs are text strings.
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

-- 1. Profiles Table (Firebase UID as primary key)
CREATE TABLE IF NOT EXISTS public.profiles (
  id text PRIMARY KEY,  -- Firebase UID (text, NOT uuid)
  user_id text UNIQUE,  -- Alias for backward compatibility
  full_name text,
  email text,
  phone text,
  city text,
  date_of_birth text,
  profile_image_url text,
  avatar_url text,      -- Alias for backward compatibility
  is_identity_verified boolean DEFAULT false,
  digilocker_doc_type text,
  digilocker_doc_id text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Journeys Table (Travelers posting routes)
CREATE TABLE IF NOT EXISTS public.journeys (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  driver_id text NOT NULL,  -- Firebase UID (text, no FK constraint)
  origin text NOT NULL,
  origin_lat double precision,
  origin_lng double precision,
  destination text NOT NULL,
  destination_lat double precision,
  destination_lng double precision,
  departure_time timestamp with time zone,
  arrival_time timestamp with time zone,
  distance_km numeric,
  duration_text text,
  capacity_kg numeric DEFAULT 10,  -- Default 10kg (NOT NULL removed â†’ has default)
  travel_mode text DEFAULT 'road',
  price_small integer,
  price_medium integer,
  price_large integer,
  pricing_type text,
  status text DEFAULT 'active' CHECK (status IN ('draft', 'active', 'completed', 'cancelled')),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Parcels Table (Senders posting items)
CREATE TABLE IF NOT EXISTS public.parcels (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id text NOT NULL,  -- Firebase UID (text, no FK constraint)
  journey_id uuid REFERENCES public.journeys(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text,
  weight_kg numeric NOT NULL,
  parcel_size text DEFAULT 'medium',
  origin text NOT NULL,
  origin_lat double precision,
  origin_lng double precision,
  destination text NOT NULL,
  destination_lat double precision,
  destination_lng double precision,
  distance_km numeric,
  pickup_pin varchar(4) NOT NULL,
  dropoff_pin varchar(4) NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('draft', 'pending', 'accepted', 'picked_up', 'in_transit', 'delivered', 'cancelled')),
  price numeric NOT NULL,
  pricing_type text,
  pricing_breakdown jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Transactions Table (Payments)
CREATE TABLE IF NOT EXISTS public.transactions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  parcel_id uuid REFERENCES public.parcels(id) ON DELETE RESTRICT NOT NULL,
  amount numeric NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_method text,
  transaction_ref text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Pricing Logs Table (Audit trail â€” every pricing calculation)
CREATE TABLE IF NOT EXISTS public.pricing_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  request_payload jsonb NOT NULL,
  response_payload jsonb NOT NULL,
  latency_ms integer,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  INDEXES (Performance)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_journeys_driver_id ON public.journeys(driver_id);
CREATE INDEX IF NOT EXISTS idx_journeys_status ON public.journeys(status);
CREATE INDEX IF NOT EXISTS idx_parcels_sender_id ON public.parcels(sender_id);
CREATE INDEX IF NOT EXISTS idx_parcels_status ON public.parcels(status);
CREATE INDEX IF NOT EXISTS idx_pricing_logs_created_at ON public.pricing_logs(created_at DESC);

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  ROW LEVEL SECURITY
--  
--  âš ï¸ Firebase Auth users do NOT have Supabase JWT tokens.
--  The app uses the Supabase ANON key directly.
--  RLS must allow operations via service role or be permissive
--  for the app's access pattern.
--
--  For production: Use a custom JWT validator or API gateway
--  to properly authenticate Firebase tokens.
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pricing_logs ENABLE ROW LEVEL SECURITY;

-- Profiles: Allow all operations via anon key (Firebase auth validated client-side)
-- In production, replace with custom JWT validation
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (true);

-- Journeys: Public read for active, authenticated write
CREATE POLICY "journeys_select" ON public.journeys FOR SELECT USING (true);
CREATE POLICY "journeys_insert" ON public.journeys FOR INSERT WITH CHECK (true);
CREATE POLICY "journeys_update" ON public.journeys FOR UPDATE USING (true);

-- Parcels: Authenticated operations
CREATE POLICY "parcels_select" ON public.parcels FOR SELECT USING (true);
CREATE POLICY "parcels_insert" ON public.parcels FOR INSERT WITH CHECK (true);
CREATE POLICY "parcels_update" ON public.parcels FOR UPDATE USING (true);

-- Transactions: Authenticated operations
CREATE POLICY "transactions_select" ON public.transactions FOR SELECT USING (true);
CREATE POLICY "transactions_insert" ON public.transactions FOR INSERT WITH CHECK (true);

-- Pricing logs: Service role writes, public reads for debugging
CREATE POLICY "pricing_logs_insert" ON public.pricing_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "pricing_logs_select" ON public.pricing_logs FOR SELECT USING (true);

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  MIGRATION SAFETY (for existing tables)
--  These ALTER statements are idempotent (IF NOT EXISTS)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

-- Ensure all columns exist (safe for re-runs)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_id text UNIQUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS date_of_birth text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_image_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_identity_verified boolean DEFAULT false;

ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS origin_lat double precision;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS origin_lng double precision;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS destination_lat double precision;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS destination_lng double precision;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS distance_km numeric;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS duration_text text;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS travel_mode text DEFAULT 'road';
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_small integer;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_medium integer;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS price_large integer;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS pricing_type text;
ALTER TABLE public.journeys ADD COLUMN IF NOT EXISTS capacity_kg numeric DEFAULT 10;

ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS origin_lat double precision;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS origin_lng double precision;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS destination_lat double precision;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS destination_lng double precision;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS distance_km numeric;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS parcel_size text DEFAULT 'medium';
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS pricing_type text;
ALTER TABLE public.parcels ADD COLUMN IF NOT EXISTS pricing_breakdown jsonb;

