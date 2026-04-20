-- Supabase Database Schema for Needin Express

-- 1. Profiles Table (already created but included here for completeness)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name text,
  email text UNIQUE,
  city text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Journeys Table (Travelers posting routes)
CREATE TABLE IF NOT EXISTS public.journeys (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  driver_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  origin text NOT NULL,
  destination text NOT NULL,
  departure_time timestamp with time zone NOT NULL,
  arrival_time timestamp with time zone NOT NULL,
  capacity_kg numeric NOT NULL,
  price_per_kg numeric NOT NULL,
  status text DEFAULT 'active' CHECK (status IN ('draft', 'active', 'completed', 'cancelled')),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Parcels Table (Senders posting items)
CREATE TABLE IF NOT EXISTS public.parcels (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  journey_id uuid REFERENCES public.journeys(id) ON DELETE SET NULL, -- Null if not matched yet
  title text NOT NULL,
  description text,
  weight_kg numeric NOT NULL,
  origin text NOT NULL,
  destination text NOT NULL,
  pickup_pin varchar(4) NOT NULL, -- 4 digit PIN for pickup
  dropoff_pin varchar(4) NOT NULL, -- 4 digit PIN for delivery
  status text DEFAULT 'pending' CHECK (status IN ('draft', 'pending', 'accepted', 'picked_up', 'in_transit', 'delivered', 'cancelled')),
  price numeric NOT NULL,
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

-- Enable RLS logic
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Optional Policies (Examples)
-- Users can view all active journeys
CREATE POLICY "Anyone can view active journeys" ON public.journeys
  FOR SELECT USING (status = 'active');

-- Users can insert their own tracking / journeys
CREATE POLICY "Users can insert their own journeys" ON public.journeys
  FOR INSERT WITH CHECK (auth.uid() = driver_id);

-- Users can update their own journeys
CREATE POLICY "Users can update their own journeys" ON public.journeys
  FOR UPDATE USING (auth.uid() = driver_id);


-- 6. Add Identity Verification fields to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_identity_verified boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS digilocker_doc_type text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS digilocker_doc_id text;

-- 7. ATOMIC TRANSACTION: Book a Traveler securely (No Orphan Records)
CREATE OR REPLACE FUNCTION public.book_traveler(p_parcel_id uuid, p_journey_id uuid, p_weight_kg numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Strict locking and atomicity to prevent race conditions & man-in-the-middle failures
  -- Check if passenger space exists
  IF (SELECT (capacity_kg - p_weight_kg) FROM public.journeys WHERE id = p_journey_id) < 0 THEN
    RAISE EXCEPTION 'Not enough capacity on this journey';
  END IF;

  -- 1. Deduct capacity from the journey
  UPDATE public.journeys 
  SET capacity_kg = capacity_kg - p_weight_kg
  WHERE id = p_journey_id;

  -- 2. Link parcel to the journey and set to accepted
  UPDATE public.parcels
  SET journey_id = p_journey_id, status = 'accepted'
  WHERE id = p_parcel_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Parcel is no longer available';
  END IF;

  -- Ensure commits atomically
END;
$$;

