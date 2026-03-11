-- Migration 009: Add RPC function to clean up old completed schedules
-- Deletes schedules where is_completed = true AND older than 7 days,
-- along with their extension_requests and comments (via ON DELETE CASCADE).

CREATE OR REPLACE FUNCTION public.cleanup_old_schedules()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted INT;
BEGIN
  -- Delete completed schedules older than 7 days.
  -- Use updated_at if available (set when marked completed),
  -- otherwise fall back to the schedule date itself.
  DELETE FROM schedules
  WHERE is_completed = true
    AND COALESCE(updated_at, date + interval '1 day') < now() - interval '7 days';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_old_schedules() TO authenticated;

-- Ensure updated_at trigger exists on schedules table
-- (already created in 001_init.sql, but guard against missing it)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Only create trigger if it does not exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_schedules_updated_at'
  ) THEN
    CREATE TRIGGER set_schedules_updated_at
      BEFORE UPDATE ON schedules
      FOR EACH ROW
      EXECUTE FUNCTION set_updated_at();
  END IF;
END;
$$;
