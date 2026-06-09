-- ══════════════════════════════════════════════════════════════
--  NEEDIN EXPRESS — Messaging System Migration
--  Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id UUID,
  journey_id UUID,
  traveler_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  last_message TEXT,
  last_message_time TIMESTAMPTZ DEFAULT NOW(),
  unread_count_sender INT DEFAULT 0,
  unread_count_traveler INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_user_id TEXT NOT NULL,
  message_text TEXT NOT NULL,
  message_type TEXT DEFAULT 'text',
  is_read BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_traveler ON conversations(traveler_id);
CREATE INDEX IF NOT EXISTS idx_conversations_sender ON conversations(sender_id);
CREATE INDEX IF NOT EXISTS idx_conversations_booking ON conversations(booking_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Allow all operations for now (Firebase Auth — RLS via app-level checks)
CREATE POLICY "Allow all conversations" ON conversations FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all messages" ON messages FOR ALL USING (true) WITH CHECK (true);
