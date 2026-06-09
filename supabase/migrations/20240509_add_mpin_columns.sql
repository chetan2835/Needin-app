-- ══════════════════════════════════════════════════════════════
--  NEEDIN EXPRESS — Auth Hardening Migration
--  Adds missing MPIN and auth columns to profiles table.
--  Run this in Supabase SQL Editor.
--  All statements are idempotent (safe to re-run).
-- ══════════════════════════════════════════════════════════════

-- Add MPIN and auth columns (missing from original schema)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mpin_hash text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mpin_attempts integer DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS mpin_locked_at timestamp with time zone;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role text DEFAULT 'user';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- Add photo_url alias (set-mpin selects this column)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS photo_url text;

-- Index for faster MPIN lookup
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);
CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON public.profiles(is_active);

-- Ensure upsert conflict target works
-- (id is already PRIMARY KEY, so this is guaranteed)

-- ══════════════════════════════════════════════════════════════
--  Verify migration
-- ══════════════════════════════════════════════════════════════
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND table_schema = 'public'
ORDER BY ordinal_position;
