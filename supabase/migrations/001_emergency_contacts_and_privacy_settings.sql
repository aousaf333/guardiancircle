-- Emergency Contacts table
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  relationship TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Privacy Settings table
CREATE TABLE IF NOT EXISTS privacy_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  location_sharing BOOLEAN NOT NULL DEFAULT true,
  invisible_mode BOOLEAN NOT NULL DEFAULT false,
  notifications BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS policies for emergency_contacts
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own emergency contacts"
  ON emergency_contacts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own emergency contacts"
  ON emergency_contacts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own emergency contacts"
  ON emergency_contacts FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own emergency contacts"
  ON emergency_contacts FOR DELETE
  USING (auth.uid() = user_id);

-- RLS policies for privacy_settings
ALTER TABLE privacy_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own privacy settings"
  ON privacy_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own privacy settings"
  ON privacy_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own privacy settings"
  ON privacy_settings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own privacy settings"
  ON privacy_settings FOR DELETE
  USING (auth.uid() = user_id);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_privacy_settings_user_id ON privacy_settings(user_id);
