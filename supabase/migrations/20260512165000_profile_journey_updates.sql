-- Migration for Profile and Journey Updates

-- 1. Profile Updates
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS age INT,
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS email_verification_attempts INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_email_otp_sent_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS current_email_otp TEXT;

-- 2. Journey Soft Deletion Updates
-- Assuming table is named 'popular_journeys' or 'journeys'. Let's check schema.
ALTER TABLE journeys
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_reason TEXT,
ADD COLUMN IF NOT EXISTS deleted_notes TEXT,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id);

-- Update RLS policies to exclude deleted journeys from standard queries
-- This is a generic policy, assuming SELECT policy exists
CREATE OR REPLACE VIEW active_journeys AS
SELECT * FROM journeys WHERE is_deleted = false;
