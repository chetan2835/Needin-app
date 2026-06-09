-- Migration to add profile completion and identity verification flags

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_profile_complete BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_identity_verified BOOLEAN DEFAULT FALSE;
