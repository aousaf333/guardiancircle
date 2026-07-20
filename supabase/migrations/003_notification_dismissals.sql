-- Notification dismissals: tracks which users have dismissed which SOS alerts
CREATE TABLE IF NOT EXISTS notification_dismissals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_id UUID NOT NULL REFERENCES emergency_alerts(id) ON DELETE CASCADE,
  dismissed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, alert_id)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_notification_dismissals_user_id
  ON notification_dismissals(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_dismissals_alert_id
  ON notification_dismissals(alert_id);
CREATE INDEX IF NOT EXISTS idx_notification_dismissals_user_alert
  ON notification_dismissals(user_id, alert_id);

-- Enable RLS
ALTER TABLE notification_dismissals ENABLE ROW LEVEL SECURITY;

-- Users can view their own dismissals
CREATE POLICY "Users can view their own dismissals"
  ON notification_dismissals FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own dismissals
CREATE POLICY "Users can insert their own dismissals"
  ON notification_dismissals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own dismissals
CREATE POLICY "Users can delete their own dismissals"
  ON notification_dismissals FOR DELETE
  USING (auth.uid() = user_id);
