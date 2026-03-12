-- Migration: 013_create_push_webhook_triggers
-- Adds pg_net-based HTTP invocation of the send-push Edge Function.
-- The existing trigger functions from 012 are updated (CREATE OR REPLACE)
-- to call invoke_send_push after a successful dedup insert.
--
-- Requirements:
--   app.settings.supabase_url  — set via: ALTER DATABASE postgres SET app.settings.supabase_url = '...';
--   app.settings.service_role_key — set via: ALTER DATABASE postgres SET app.settings.service_role_key = '...';
-- See docs/database_webhooks_setup.md for full setup instructions.

-- ============================================================
-- 1. Enable pg_net extension (no-op if already enabled)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ============================================================
-- 2. notify_push_event (BOOLEAN variant)
--    Replaces the VOID version from 012.
--    Returns TRUE if the dedup INSERT succeeded (new event),
--    FALSE if the event_key already existed (conflict → skip).
--    In PL/pgSQL, FOUND is only set by SELECT INTO / DML, NOT by
--    PERFORM, so callers must use the return value directly:
--      IF public.notify_push_event(...) THEN ...
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_push_event(
  p_event_key  TEXT,
  p_event_type TEXT,
  p_payload    JSONB
) RETURNS BOOLEAN AS $$
BEGIN
  INSERT INTO public.notification_events (event_key, event_type, payload)
  VALUES (p_event_key, p_event_type, p_payload)
  ON CONFLICT (event_key) DO NOTHING;

  IF FOUND THEN
    PERFORM pg_notify('push_events', p_payload::text);
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. invoke_send_push
--    Calls the send-push Edge Function via HTTP POST using pg_net.
--    Silently skips (with a WARNING) if the required database
--    settings are not configured, so triggers never hard-fail.
-- ============================================================
CREATE OR REPLACE FUNCTION public.invoke_send_push(p_payload JSONB)
RETURNS VOID AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_role_key TEXT;
BEGIN
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_role_key := current_setting('app.settings.service_role_key', true);

  IF v_supabase_url IS NULL OR v_supabase_url = ''
     OR v_service_role_key IS NULL OR v_service_role_key = ''
  THEN
    RAISE WARNING 'invoke_send_push: skipped — app.settings.supabase_url or app.settings.service_role_key not configured';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url     := v_supabase_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body    := p_payload
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. Updated trigger function: announcements
--    Replaces the version from 012.
--    After a successful dedup insert, invokes the Edge Function
--    for broadcast announcements.
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_announcement_push()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = true THEN
    -- notify_push_event returns TRUE if the event is new (dedup passed).
    -- Using the return value directly avoids the PERFORM+IF FOUND anti-pattern
    -- (FOUND is never set after PERFORM of a non-DML function).
    IF public.notify_push_event(
      'announcement:' || NEW.id::text,
      'announcement',
      jsonb_build_object(
        'type',            'announcement',
        'announcement_id', NEW.id,
        'title',           NEW.title,
        'message',         NEW.message,
        'broadcast',       true
      )
    ) THEN
      PERFORM public.invoke_send_push(
        jsonb_build_object(
          'type',      'announcement',
          'broadcast', true,
          'title',     'Limpy - ' || COALESCE(NEW.title, 'Nuevo Anuncio'),
          'body',      COALESCE(NEW.message, ''),
          'data',      jsonb_build_object(
            'type',            'announcement',
            'announcement_id', NEW.id::text,
            'title',           COALESCE(NEW.title, 'Nuevo Anuncio'),
            'message',         COALESCE(NEW.message, '')
          )
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. Updated trigger function: extension_requests
--    Replaces the version from 012.
--    Looks up the requester's display name from profiles and
--    includes it in the push payload.
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_extension_request_push()
RETURNS TRIGGER AS $$
DECLARE
  v_requester_name TEXT;
BEGIN
  -- Look up requester display name for richer notification content.
  SELECT name INTO v_requester_name
  FROM public.profiles
  WHERE id = NEW.requester_id;

  IF NEW.status = 'pending' THEN
    IF public.notify_push_event(
      'extension_request:' || NEW.id::text || ':pending',
      'extension_request',
      jsonb_build_object(
        'type',           'extension_request',
        'request_id',     NEW.id,
        'requester_id',   NEW.requester_id,
        'target_user_id', NEW.next_user_id,
        'status',         'pending'
      )
    ) THEN
      PERFORM public.invoke_send_push(
        jsonb_build_object(
          'type',     'extension_request',
          'user_ids', jsonb_build_array(NEW.next_user_id),
          'title',    'Limpy - Solicitud de Prórroga',
          'body',     COALESCE(v_requester_name, 'Alguien') || ' solicita una prórroga.',
          'data',     jsonb_build_object(
            'type',           'extension_request',
            'request_id',     NEW.id,
            'requester_id',   NEW.requester_id,
            'requester_name', COALESCE(v_requester_name, ''),
            'status',         'pending'
          )
        )
      );
    END IF;

  ELSIF NEW.status = 'accepted' THEN
    IF public.notify_push_event(
      'extension_request:' || NEW.id::text || ':accepted',
      'extension_request',
      jsonb_build_object(
        'type',           'extension_request',
        'request_id',     NEW.id,
        'requester_id',   NEW.requester_id,
        'target_user_id', NEW.next_user_id,
        'status',         'accepted'
      )
    ) THEN
      PERFORM public.invoke_send_push(
        jsonb_build_object(
          'type',     'extension_request',
          'user_ids', jsonb_build_array(NEW.requester_id),
          'title',    'Limpy - Prórroga Aceptada',
          'body',     'Tu solicitud de prórroga fue aceptada.',
          'data',     jsonb_build_object(
            'type',       'extension_request',
            'request_id', NEW.id,
            'status',     'accepted'
          )
        )
      );
    END IF;

  ELSIF NEW.status = 'rejected' THEN
    IF public.notify_push_event(
      'extension_request:' || NEW.id::text || ':rejected',
      'extension_request',
      jsonb_build_object(
        'type',           'extension_request',
        'request_id',     NEW.id,
        'requester_id',   NEW.requester_id,
        'target_user_id', NEW.next_user_id,
        'status',         'rejected'
      )
    ) THEN
      PERFORM public.invoke_send_push(
        jsonb_build_object(
          'type',     'extension_request',
          'user_ids', jsonb_build_array(NEW.requester_id),
          'title',    'Limpy - Prórroga Rechazada',
          'body',     'Tu solicitud de prórroga fue rechazada.',
          'data',     jsonb_build_object(
            'type',       'extension_request',
            'request_id', NEW.id,
            'status',     'rejected'
          )
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. Updated trigger function: comments
--    Replaces the version from 012.
--    Sends push to the schedule owner when a new comment arrives.
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_comment_push()
RETURNS TRIGGER AS $$
DECLARE
  v_schedule_user_id UUID;
BEGIN
  -- Find the user responsible for this schedule.
  SELECT user_id INTO v_schedule_user_id
  FROM public.schedules
  WHERE id = NEW.schedule_id;

  IF v_schedule_user_id IS NOT NULL
     AND v_schedule_user_id != COALESCE(NEW.sender_id, '00000000-0000-0000-0000-000000000000'::uuid)
  THEN
    IF public.notify_push_event(
      'comment:' || NEW.id::text,
      'comment',
      jsonb_build_object(
        'type',           'comment',
        'comment_id',     NEW.id,
        'schedule_id',    NEW.schedule_id,
        'target_user_id', v_schedule_user_id
      )
    ) THEN
      PERFORM public.invoke_send_push(
        jsonb_build_object(
          'type',     'comment',
          'user_ids', jsonb_build_array(v_schedule_user_id),
          'title',    'Limpy - Nuevo Comentario',
          'body',     'Tienes un nuevo comentario en tu turno.',
          'data',     jsonb_build_object(
            'type',        'comment',
            'comment_id',  NEW.id,
            'schedule_id', NEW.schedule_id
          )
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
