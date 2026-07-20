-- Emergency Alerts table
CREATE TABLE IF NOT EXISTS emergency_alerts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  cancelled_at TIMESTAMPTZ
);

-- Indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_family_id ON emergency_alerts(family_id);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_sender_id ON emergency_alerts(sender_id);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_status ON emergency_alerts(status);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_family_status ON emergency_alerts(family_id, status);

-- Enable RLS
ALTER TABLE emergency_alerts ENABLE ROW LEVEL SECURITY;

-- Family members can view alerts for their families
CREATE POLICY "Family members can view alerts"
  ON emergency_alerts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM family_members
      WHERE family_members.family_id = emergency_alerts.family_id
      AND family_members.user_id = auth.uid()
    )
  );

-- Users can create alerts for families they belong to
CREATE POLICY "Users can create alerts for their families"
  ON emergency_alerts FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM family_members
      WHERE family_members.family_id = emergency_alerts.family_id
      AND family_members.user_id = auth.uid()
    )
  );

-- Senders can update their own alerts (for cancellation and location updates)
CREATE POLICY "Senders can update their own alerts"
  ON emergency_alerts FOR UPDATE
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);

-- Senders can delete their own alerts
CREATE POLICY "Senders can delete their own alerts"
  ON emergency_alerts FOR DELETE
  USING (auth.uid() = sender_id);
