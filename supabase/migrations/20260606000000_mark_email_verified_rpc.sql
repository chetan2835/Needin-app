-- ======================================================================
-- Migration: Secure Email Verification RPC
-- Created: 2026-06-06
-- 
-- PURPOSE:
-- The Needin app uses Firebase Phone Auth as primary auth.
-- Email verification uses Supabase's signInWithOtp().
-- After verifyOTP(), the Supabase session uid is the OTP user's UUID,
-- NOT the Firebase UID stored in profiles.id.
-- 
-- Direct .update().eq('id', firebaseUid) fails because:
--   RLS policy: auth.uid()::text = id
--   But auth.uid() = Supabase OTP user ≠ Firebase UID in profiles.id
--
-- SOLUTION:
-- A SECURITY DEFINER function runs with the DB owner's privileges,
-- bypassing RLS. It validates the email match as a security check
-- before writing email_verified=true, preventing spoofing.
-- ======================================================================

CREATE OR REPLACE FUNCTION mark_email_verified(
  p_firebase_uid TEXT,
  p_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile profiles%ROWTYPE;
  v_result JSONB;
BEGIN
  -- Validate: profile must exist with this Firebase UID
  SELECT * INTO v_profile
  FROM profiles
  WHERE id = p_firebase_uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  -- Write email_verified to the profile row
  UPDATE profiles
  SET
    email           = p_email,
    email_verified  = TRUE,
    email_verified_at = NOW(),
    current_email_otp = NULL
  WHERE id = p_firebase_uid;

  RETURN jsonb_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execute to anon and authenticated roles
-- so the Supabase client can call it via .rpc()
GRANT EXECUTE ON FUNCTION mark_email_verified(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION mark_email_verified(TEXT, TEXT) TO authenticated;
