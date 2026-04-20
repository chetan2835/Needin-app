-- ============================================================
-- DigiLocker sessions (PKCE + state — short-lived)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.digilocker_sessions (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      TEXT        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  state        TEXT        NOT NULL UNIQUE,
  code_verifier TEXT       NOT NULL,
  expires_at   TIMESTAMPTZ NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_digilocker_sessions_state   ON digilocker_sessions(state);
CREATE INDEX IF NOT EXISTS idx_digilocker_sessions_user_id ON digilocker_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_digilocker_sessions_expires ON digilocker_sessions(expires_at);

-- Auto-purge expired sessions (pg_cron — enable in Supabase Dashboard > Extensions)
-- SELECT cron.schedule('purge-digilocker-sessions', '*/15 * * * *',
--   $$DELETE FROM public.digilocker_sessions WHERE expires_at < NOW()$$);

-- ============================================================
-- DigiLocker verifications (permanent record per user)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.digilocker_verifications (
  id                    UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id               TEXT        NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  digilocker_id         TEXT,
  name                  TEXT,
  date_of_birth         TEXT,
  gender                TEXT,
  reference_key         TEXT,
  raw_userprofile       JSONB,
  raw_issued_files      JSONB,
  access_token_encrypted  TEXT,       -- AES-256-GCM encrypted
  refresh_token_encrypted TEXT,       -- AES-256-GCM encrypted (nullable)
  token_expires_at      TIMESTAMPTZ,
  verification_status   TEXT        NOT NULL DEFAULT 'pending'
                          CHECK (verification_status IN ('pending','verified','failed')),
  verified_at           TIMESTAMPTZ,
  failure_reason        TEXT,
  attempt_count         INT         NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_digilocker_verif_user_id ON digilocker_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_digilocker_verif_status  ON digilocker_verifications(verification_status);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;
CREATE TRIGGER trg_digilocker_verif_updated_at
  BEFORE UPDATE ON public.digilocker_verifications
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Add columns to profiles table
-- ============================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_identity_verified   BOOLEAN     DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS identity_verified_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS identity_provider      TEXT;

-- ============================================================
-- Row-Level Security
-- ============================================================
ALTER TABLE public.digilocker_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digilocker_verifications ENABLE ROW LEVEL SECURITY;

-- Users can only read their OWN verification record (not sessions)
CREATE POLICY "user_read_own_verification"
  ON public.digilocker_verifications FOR SELECT
  USING (auth.uid() = user_id);

-- Only service_role (Edge Functions) can write to these tables
CREATE POLICY "service_role_all_sessions"
  ON public.digilocker_sessions FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "service_role_all_verifications"
  ON public.digilocker_verifications FOR ALL
  USING (auth.role() = 'service_role');
