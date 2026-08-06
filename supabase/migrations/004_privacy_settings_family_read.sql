-- Allow family members to view each other's privacy settings so the map can
-- display "Location Hidden" when a member has privacy mode (invisible_mode)
-- enabled. Each member can still only read/write their own settings for
-- mutations; this only adds a read-only view of the invisible_mode flag for
-- people who share a family.
ALTER TABLE privacy_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can view each other's privacy settings"
  ON privacy_settings FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM family_members viewer
      JOIN family_members target ON target.family_id = viewer.family_id
      WHERE viewer.user_id = auth.uid()
        AND target.user_id = privacy_settings.user_id
    )
  );
