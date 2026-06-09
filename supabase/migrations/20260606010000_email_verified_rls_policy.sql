-- ======================================================================
-- Migration: Email Verification — Email-Based Update Policy
-- Created: 2026-06-06
--
-- PURPOSE:
-- After signInWithOtp() + verifyOTP(), the Supabase session's auth.email()
-- equals the verified email address. Add a policy that allows a profile
-- update when the row's email column matches auth.email().
-- This is the correct RLS approach for email-based verification.
-- ======================================================================

-- Drop the old complex RPC (no longer needed)
DROP FUNCTION IF EXISTS mark_email_verified(TEXT, TEXT);

-- Add email-based UPDATE policy so the OTP session can write email_verified
DROP POLICY IF EXISTS profiles_update_by_email ON public.profiles;
CREATE POLICY profiles_update_by_email ON public.profiles
  FOR UPDATE
  USING (email::text = auth.email());
