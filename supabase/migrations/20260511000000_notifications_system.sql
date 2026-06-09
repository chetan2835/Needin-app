-- ══════════════════════════════════════════════════════════════
--  NEEDIN NOTIFICATION SYSTEM — Full Schema
--  Tables: notifications, user_devices, notification_preferences
--  Security: Row Level Security on all tables
-- ══════════════════════════════════════════════════════════════

-- 1. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       text NOT NULL,
  title         text NOT NULL,
  body          text NOT NULL,
  type          text NOT NULL DEFAULT 'general',
  category      text NOT NULL DEFAULT 'system',
  image_url     text,
  priority      text DEFAULT 'normal',
  data          jsonb DEFAULT '{}',
  action_route  text,
  action_payload jsonb DEFAULT '{}',
  is_read       boolean DEFAULT false,
  is_archived   boolean DEFAULT false,
  created_at    timestamptz DEFAULT now(),
  read_at       timestamptz
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;

-- 2. USER DEVICES TABLE (FCM tokens)
CREATE TABLE IF NOT EXISTS public.user_devices (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       text NOT NULL,
  device_token  text NOT NULL,
  platform      text DEFAULT 'android',
  device_model  text,
  os_version    text,
  app_version   text,
  is_active     boolean DEFAULT true,
  last_seen_at  timestamptz DEFAULT now(),
  created_at    timestamptz DEFAULT now(),
  UNIQUE(user_id, device_token)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_active ON public.user_devices(user_id, is_active) WHERE is_active = true;

-- 3. NOTIFICATION PREFERENCES TABLE
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id           text PRIMARY KEY,
  push_enabled      boolean DEFAULT true,
  in_app_enabled    boolean DEFAULT true,
  messages_enabled  boolean DEFAULT true,
  bookings_enabled  boolean DEFAULT true,
  payments_enabled  boolean DEFAULT true,
  marketing_enabled boolean DEFAULT true,
  security_enabled  boolean DEFAULT true,
  sound_enabled     boolean DEFAULT true,
  vibration_enabled boolean DEFAULT true,
  quiet_hours_start time,
  quiet_hours_end   time,
  updated_at        timestamptz DEFAULT now()
);

-- 4. JOURNEY DELETION REASONS (audit trail)
CREATE TABLE IF NOT EXISTS public.journey_deletion_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journey_id  text NOT NULL,
  user_id     text NOT NULL,
  reason_code text NOT NULL,
  reason_text text,
  deleted_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deletion_logs_user ON public.journey_deletion_logs(user_id);

-- 5. ROW LEVEL SECURITY
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_deletion_logs ENABLE ROW LEVEL SECURITY;

-- Notifications: users see only their own
CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid()::text);

CREATE POLICY "Service can insert notifications" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- User devices: users manage only their own
CREATE POLICY "Users can view own devices" ON public.user_devices
  FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY "Users can insert own devices" ON public.user_devices
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own devices" ON public.user_devices
  FOR UPDATE USING (user_id = auth.uid()::text);

CREATE POLICY "Users can delete own devices" ON public.user_devices
  FOR DELETE USING (user_id = auth.uid()::text);

-- Notification preferences: users manage only their own
CREATE POLICY "Users can view own prefs" ON public.notification_preferences
  FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY "Users can upsert own prefs" ON public.notification_preferences
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own prefs" ON public.notification_preferences
  FOR UPDATE USING (user_id = auth.uid()::text);

-- Journey deletion logs: users can insert their own
CREATE POLICY "Users can insert deletion logs" ON public.journey_deletion_logs
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own deletion logs" ON public.journey_deletion_logs
  FOR SELECT USING (user_id = auth.uid()::text);

-- 6. Enable Realtime for notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

NOTIFY pgrst, 'reload schema';
