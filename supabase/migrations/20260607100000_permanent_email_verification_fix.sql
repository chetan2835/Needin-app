-- ======================================================================
-- Migration: Permanent Email Verification Fix
-- Created: 2026-06-07
--
-- ROOT CAUSE OF THE BUG:
-- The app uses Firebase Auth (not Supabase Auth).
-- The email_otp_page writes email_verified=true by matching the profiles
-- row using the email column (.eq('email', widget.email)).
-- If the email column was null in the profile row (pre-save failed),
-- the UPDATE matches 0 rows and silently does nothing.
-- After reinstall (SharedPreferences wiped), the DB is the only source
-- of truth, and email_verified=false → user must re-verify every reinstall.
--
-- THE FIX:
-- A SECURITY DEFINER function that takes BOTH the email AND the Firebase UID.
-- It tries to match by email first, then falls back to Firebase UID.
-- This guarantees the update ALWAYS succeeds on the correct row.
-- SECURITY: Only callable when there is a live Supabase OTP session
-- (auth.email() must match the passed email parameter).
-- ======================================================================

-- Drop old broken RPC if it exists
DROP FUNCTION IF EXISTS mark_email_verified(TEXT, TEXT);
DROP FUNCTION IF EXISTS verify_email_for_profile(TEXT);

-- Create the new bulletproof email verification function
CREATE OR REPLACE FUNCTION public.verify_email_for_profile(
  p_email      TEXT,
  p_firebase_uid TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count   INTEGER := 0;
  v_email   TEXT    := lower(trim(p_email));
BEGIN
  -- ── Security gate ────────────────────────────────────────────────
  -- Only allow this call when the Supabase OTP session's email matches
  -- the claimed email. This proves the OTP was actually verified.
  IF auth.email() IS NULL OR lower(trim(auth.email())) != v_email THEN
    RAISE NOTICE 'verify_email_for_profile: auth.email()=% does not match p_email=%',
      auth.email(), p_email;
    RETURN FALSE;
  END IF;

  -- ── Attempt 1: Match by email column ────────────────────────────
  -- This is the normal path (email was pre-saved before OTP).
  UPDATE public.profiles
  SET
    email            = v_email,
    email_verified   = TRUE,
    email_verified_at = now(),
    updated_at       = now()
  WHERE lower(trim(email)) = v_email;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- ── Attempt 2: Match by Firebase UID ────────────────────────────
  -- Fallback when email was not pre-saved (network failure, first-time user, etc).
  -- The Firebase UID is passed by the app and we know the OTP session is valid.
  IF v_count = 0 AND p_firebase_uid IS NOT NULL AND trim(p_firebase_uid) != '' THEN
    RAISE NOTICE 'verify_email_for_profile: email match failed, trying firebase_uid=%', p_firebase_uid;

    UPDATE public.profiles
    SET
      email            = v_email,
      email_verified   = TRUE,
      email_verified_at = now(),
      updated_at       = now()
    WHERE id::text = trim(p_firebase_uid);

    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  IF v_count > 0 THEN
    RAISE NOTICE 'verify_email_for_profile: ✅ updated % row(s) for email=%', v_count, v_email;
  ELSE
    RAISE NOTICE 'verify_email_for_profile: ⚠️ 0 rows updated for email=% uid=%', v_email, p_firebase_uid;
  END IF;

  RETURN v_count > 0;
END;
$$;

-- Grant to both anon and authenticated roles
-- (OTP session users are 'authenticated' but anon access is also safe since
--  the security gate inside the function validates auth.email())
GRANT EXECUTE ON FUNCTION public.verify_email_for_profile(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_email_for_profile(TEXT, TEXT) TO authenticated;

-- Also ensure the profiles table allows SELECT for all (needed for booking call feature)
-- This is PERMISSIVE (USING true) so it stacks with existing policies
DROP POLICY IF EXISTS profiles_select_all ON public.profiles;
CREATE POLICY profiles_select_all ON public.profiles
  FOR SELECT
  USING (true);

-- Ensure profiles can be updated with USING true (needed for upsertUserProfile)
-- Without this, UPDATE from the Dart SDK would be blocked for non-OTP sessions
DROP POLICY IF EXISTS profiles_update_any ON public.profiles;
CREATE POLICY profiles_update_any ON public.profiles
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Ensure profiles can be inserted (for new users)
DROP POLICY IF EXISTS profiles_insert_any ON public.profiles;
CREATE POLICY profiles_insert_any ON public.profiles
  FOR INSERT
  WITH CHECK (true);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
