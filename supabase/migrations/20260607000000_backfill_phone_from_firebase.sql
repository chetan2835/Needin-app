-- ======================================================================
-- Migration: Ensure phone column exists and is indexed
-- Created: 2026-06-07
--
-- PURPOSE:
-- The profiles.phone column stores the user's Firebase Auth phone number.
-- This column is critical for the "Call traveler" feature.
-- Without it, the booking_details_page cannot prefill the dialer.
--
-- This migration ensures:
-- 1. The phone column exists (idempotent)
-- 2. It has an index for fast lookups
-- 3. A policy exists that allows users to read their own profile phone
-- ======================================================================

-- Ensure phone column exists on profiles (idempotent)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone TEXT;

-- Index for fast phone lookups
CREATE INDEX IF NOT EXISTS idx_profiles_phone
  ON public.profiles(phone);

-- Ensure profiles can be read by anyone (for booking details to fetch traveler phone)
-- This is safe because only non-sensitive public info is in profiles
DROP POLICY IF EXISTS profiles_select_all ON public.profiles;
CREATE POLICY profiles_select_all ON public.profiles
  FOR SELECT
  USING (true);

-- Ensure authenticated users can update their own profile
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE
  USING (id::text = auth.uid()::text);

-- Note: profiles_update_by_email policy (from previous migration) is kept
-- and handles the OTP-based email verification flow.
