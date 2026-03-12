-- Migration: 012_create_notification_events_and_triggers
-- Creates the notification_events deduplication table and trigger functions
-- for push notification delivery via pg_notify.
--
-- Old notification_events rows can be purged periodically (e.g., older than 7 days)
-- to prevent unbounded table growth.

-- ============================================================
-- 1. Create notification_events deduplication table
-- ============================================================
CREATE TABLE public.notification_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_key TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. Enable RLS — users should not access this table directly.
--    service_role retains full access (bypasses RLS by default).
-- ============================================================
ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. Helper function: notify_push_event
--    Inserts a dedup record and fires pg_notify on 'push_events'.
--    If the event_key already exists the INSERT is silently skipped
--    and pg_notify is NOT called (dedup guarantee).
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_push_event(
  p_event_key TEXT,
  p_event_type TEXT,
  p_payload JSONB
) RETURNS VOID AS $$
BEGIN
  INSERT INTO public.notification_events (event_key, event_type, payload)
  VALUES (p_event_key, p_event_type, p_payload)
  ON CONFLICT (event_key) DO NOTHING;

  IF FOUND THEN
    PERFORM pg_notify('push_events', p_payload::text);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. Trigger function: announcements
--    Fires AFTER INSERT on announcements when is_active = true.
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_announcement_push()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = true THEN
    PERFORM public.notify_push_event(
      'announcement:' || NEW.id::text,
      'announcement',
      jsonb_build_object(
        'type', 'announcement',
        'announcement_id', NEW.id,
        'title', NEW.title,
        'message', NEW.message,
        'broadcast', true
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_announcement_push
  AFTER INSERT ON public.announcements
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_announcement_push();

-- ============================================================
-- 5. Trigger function: extension_requests
--    Fires AFTER INSERT OR UPDATE on extension_requests.
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_extension_request_push()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'pending' THEN
    PERFORM public.notify_push_event(
      'extension_request:' || NEW.id::text || ':pending',
      'extension_request',
      jsonb_build_object(
        'type', 'extension_request',
        'request_id', NEW.id,
        'requester_id', NEW.requester_id,
        'target_user_id', NEW.next_user_id,
        'status', 'pending'
      )
    );
  ELSIF NEW.status IN ('accepted', 'rejected') THEN
    PERFORM public.notify_push_event(
      'extension_request:' || NEW.id::text || ':' || NEW.status,
      'extension_request',
      jsonb_build_object(
        'type', 'extension_request',
        'request_id', NEW.id,
        'requester_id', NEW.requester_id,
        'target_user_id', NEW.next_user_id,
        'status', NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_extension_request_push
  AFTER INSERT OR UPDATE ON public.extension_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_extension_request_push();

-- ============================================================
-- 6. Trigger function: comments
--    Fires AFTER INSERT on comments.
--    Looks up the schedule owner and skips if sender is the owner.
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_comment_push()
RETURNS TRIGGER AS $$
DECLARE
  v_schedule_user_id UUID;
BEGIN
  -- Find the user responsible for this schedule
  SELECT user_id INTO v_schedule_user_id
  FROM public.schedules
  WHERE id = NEW.schedule_id;

  IF v_schedule_user_id IS NOT NULL
     AND v_schedule_user_id != COALESCE(NEW.sender_id, '00000000-0000-0000-0000-000000000000'::uuid)
  THEN
    PERFORM public.notify_push_event(
      'comment:' || NEW.id::text,
      'comment',
      jsonb_build_object(
        'type', 'comment',
        'comment_id', NEW.id,
        'schedule_id', NEW.schedule_id,
        'target_user_id', v_schedule_user_id
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_comment_push
  AFTER INSERT ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_comment_push();
