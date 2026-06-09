-- ======================================================================
-- FINAL PERMANENT FIX: Firebase UID Profile System
-- 
-- STRATEGY: Instead of converting profiles.id from UUID to TEXT
-- (which requires dropping/recreating views, FKs, rules — too risky),
-- we ADD a new firebase_uid TEXT column and route all app operations
-- through RPCs that use this column.
--
-- ROOT CAUSE SUMMARY:
-- profiles.id = UUID referencing auth.users (Supabase auth)
-- Firebase UIDs = text strings (e.g. "AbCd1234xyz") — NOT valid UUIDs
-- All .insert({'id': firebaseUid}) calls fail silently (caught exceptions)
-- No profile ever saved to DB → on reinstall, local cache wiped → unverified
-- ======================================================================

-- ── 1. Remove the FK constraint from profiles.id → auth.users ──────────
-- This is necessary so we can insert profiles with RPCs that generate
-- their own UUIDs independent of Supabase auth.users.
DO $$
DECLARE
  v_constraint TEXT;
BEGIN
  SELECT tc.constraint_name INTO v_constraint
  FROM information_schema.table_constraints AS tc
  JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
  JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
  WHERE tc.table_schema = 'public'
    AND tc.table_name   = 'profiles'
    AND kcu.column_name = 'id'
    AND tc.constraint_type = 'FOREIGN KEY'
  LIMIT 1;

  IF v_constraint IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.profiles DROP CONSTRAINT ' || quote_ident(v_constraint);
  END IF;
END $$;

-- ── 2. Add new columns (all idempotent) ─────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS firebase_uid       TEXT UNIQUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone              TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email_verified     BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email_verified_at  TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_profile_complete BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS age                INTEGER;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_image_url  TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url         TEXT;

-- ── 3. Indexes for fast lookups ──────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_firebase_uid    ON public.profiles (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_profiles_phone           ON public.profiles (phone);
CREATE INDEX IF NOT EXISTS idx_profiles_email           ON public.profiles (email);
CREATE INDEX IF NOT EXISTS idx_profiles_email_verified  ON public.profiles (email_verified);

-- ── 4. Permissive RLS policies (app uses Firebase Auth, not Supabase) ───
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select_own        ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own        ON public.profiles;
DROP POLICY IF EXISTS profiles_insert_own        ON public.profiles;
DROP POLICY IF EXISTS profiles_update_by_email   ON public.profiles;
DROP POLICY IF EXISTS profiles_select_all        ON public.profiles;
DROP POLICY IF EXISTS profiles_update_any        ON public.profiles;
DROP POLICY IF EXISTS profiles_insert_any        ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile"   ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

CREATE POLICY profiles_select_all ON public.profiles FOR SELECT USING (true);
CREATE POLICY profiles_insert_any ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY profiles_update_any ON public.profiles FOR UPDATE USING (true) WITH CHECK (true);

-- ── 5. RPC: Upsert profile by Firebase UID ──────────────────────────────
-- Called by the app on every profile save. Creates or updates the profile
-- using firebase_uid as the key. Generates a proper UUID for profiles.id
-- so we never conflict with auth.users constraints.
DROP FUNCTION IF EXISTS public.upsert_profile_by_firebase_uid(TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION public.upsert_profile_by_firebase_uid(
  p_firebase_uid      TEXT,
  p_phone             TEXT    DEFAULT NULL,
  p_full_name         TEXT    DEFAULT NULL,
  p_email             TEXT    DEFAULT NULL,
  p_city              TEXT    DEFAULT NULL,
  p_age               INTEGER DEFAULT NULL,
  p_profile_image_url TEXT    DEFAULT NULL,
  p_is_complete       BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id   TEXT;
  v_existing_id  TEXT;
BEGIN
  -- Lookup by firebase_uid first
  SELECT id INTO v_existing_id FROM public.profiles
  WHERE firebase_uid = p_firebase_uid
  LIMIT 1;

  -- If not found by firebase_uid, try phone
  IF v_existing_id IS NULL AND p_phone IS NOT NULL THEN
    SELECT id INTO v_existing_id FROM public.profiles
    WHERE phone = p_phone
    LIMIT 1;
  END IF;

  IF v_existing_id IS NOT NULL THEN
    -- UPDATE existing profile (never overwrites email_verified)
    UPDATE public.profiles SET
      firebase_uid          = p_firebase_uid,
      phone                 = COALESCE(p_phone, phone),
      full_name             = COALESCE(p_full_name, full_name),
      email                 = COALESCE(p_email, email),
      city                  = COALESCE(p_city, city),
      age                   = COALESCE(p_age, age),
      profile_image_url     = COALESCE(p_profile_image_url, profile_image_url),
      avatar_url            = COALESCE(p_profile_image_url, avatar_url),
      is_profile_complete   = COALESCE(p_is_complete, is_profile_complete),
      updated_at            = now()
    WHERE id = v_existing_id;

    RETURN jsonb_build_object('id', v_existing_id, 'success', true, 'action', 'updated');
  ELSE
    -- INSERT new profile with a generated UUID for id
    v_profile_id := gen_random_uuid()::TEXT;
    INSERT INTO public.profiles (
      id, firebase_uid, phone, full_name, email, city, age,
      profile_image_url, avatar_url, is_profile_complete,
      email_verified, created_at, updated_at
    ) VALUES (
      v_profile_id, p_firebase_uid, p_phone, p_full_name, p_email, p_city, p_age,
      p_profile_image_url, p_profile_image_url, COALESCE(p_is_complete, false),
      false, now(), now()
    );

    RETURN jsonb_build_object('id', v_profile_id, 'success', true, 'action', 'inserted');
  END IF;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_profile_by_firebase_uid(TEXT,TEXT,TEXT,TEXT,TEXT,INTEGER,TEXT,BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION public.upsert_profile_by_firebase_uid(TEXT,TEXT,TEXT,TEXT,TEXT,INTEGER,TEXT,BOOLEAN) TO authenticated;

-- ── 6. RPC: Get profile by Firebase UID ─────────────────────────────────
DROP FUNCTION IF EXISTS public.get_profile_by_firebase_uid(TEXT);

CREATE OR REPLACE FUNCTION public.get_profile_by_firebase_uid(p_firebase_uid TEXT)
RETURNS SETOF public.profiles
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT * FROM public.profiles WHERE firebase_uid = p_firebase_uid LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_profile_by_firebase_uid(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_profile_by_firebase_uid(TEXT) TO authenticated;

-- ── 7. RPC: Get profile by phone number ─────────────────────────────────
DROP FUNCTION IF EXISTS public.get_profile_by_phone(TEXT);

CREATE OR REPLACE FUNCTION public.get_profile_by_phone(p_phone TEXT)
RETURNS SETOF public.profiles
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT * FROM public.profiles WHERE phone = p_phone LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_profile_by_phone(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_profile_by_phone(TEXT) TO authenticated;

-- ── 8. RPC: Permanent email verification ────────────────────────────────
DROP FUNCTION IF EXISTS public.verify_email_for_profile(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_email_for_profile(TEXT);
DROP FUNCTION IF EXISTS public.mark_email_verified(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.verify_email_for_profile(
  p_email        TEXT,
  p_firebase_uid TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER := 0;
  v_email TEXT    := lower(trim(p_email));
BEGIN
  -- Security gate: only proceed when Supabase OTP session is active
  -- (auth.email() is set during the brief OTP verification window)
  IF auth.email() IS NULL OR lower(trim(auth.email())) != v_email THEN
    RETURN FALSE;
  END IF;

  -- Attempt 1: Update by firebase_uid (most reliable)
  IF p_firebase_uid IS NOT NULL AND trim(p_firebase_uid) != '' THEN
    UPDATE public.profiles
    SET email = v_email, email_verified = TRUE, email_verified_at = now(), updated_at = now()
    WHERE firebase_uid = trim(p_firebase_uid);
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count > 0 THEN RETURN TRUE; END IF;
  END IF;

  -- Attempt 2: Update by email match (fallback)
  UPDATE public.profiles
  SET email_verified = TRUE, email_verified_at = now(), updated_at = now()
  WHERE lower(trim(email)) = v_email;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_email_for_profile(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_email_for_profile(TEXT, TEXT) TO authenticated;

-- ── 9. Reload PostgREST schema cache ────────────────────────────────────
NOTIFY pgrst, 'reload schema';

SELECT 'Migration complete. firebase_uid column added. RPCs created.' AS result;
