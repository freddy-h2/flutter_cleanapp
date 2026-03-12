-- Cleanup function for old notification_events rows.
-- Deletes events older than 7 days to prevent unbounded table growth.
-- Called periodically from the background service alongside cleanup_old_schedules.
CREATE OR REPLACE FUNCTION public.cleanup_old_notification_events()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.notification_events
  WHERE created_at < now() - interval '7 days';
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
