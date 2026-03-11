-- Add 'recordatorio' to the announcements type CHECK constraint.
-- The original constraint (005) only allowed 'aviso' and 'update'.
ALTER TABLE announcements DROP CONSTRAINT IF EXISTS announcements_type_check;
ALTER TABLE announcements ADD CONSTRAINT announcements_type_check
  CHECK (type IN ('aviso', 'recordatorio', 'update'));
