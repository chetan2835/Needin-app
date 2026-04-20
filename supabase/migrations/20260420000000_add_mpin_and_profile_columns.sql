-- supabase/migrations/20260420000000_add_mpin_and_profile_columns.sql

-- Add missing columns if they don't exist
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS phone TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS mpin_hash TEXT,
  ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS mpin_attempts INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mpin_locked_at TIMESTAMPTZ;

-- Note: The instructions assumed the table is named `users` but the existing schema
-- uses `profiles`. I am adapting the migration to the `profiles` table to preserve data.

-- Index for phone lookups (used in MPIN verification)
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

-- Trigger to auto-update updated_at on any row change
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Removed RLS policy overrides because the application uses Firebase Auth (text UIDs)
-- and permissive policies for anon key. The edge functions use service_role to bypass RLS.
