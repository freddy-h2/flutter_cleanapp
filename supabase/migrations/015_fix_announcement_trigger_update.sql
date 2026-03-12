-- Migration: 015_fix_announcement_trigger_update
-- Fixes trg_announcement_push so it also fires when an announcement is
-- updated from is_active=false to is_active=true.
--
-- Problem: migration 012 defined the trigger as AFTER INSERT only.
-- If an admin creates an announcement with is_active=false and later
-- sets it to is_active=true, no push notification was sent.
--
-- Fix:
--   1. Drop the existing INSERT-only trigger.
--   2. Update trigger_announcement_push() to guard against re-firing on
--      unrelated UPDATEs: only proceed when TG_OP='INSERT' or
--      OLD.is_active was false (i.e. the row is being activated).
--   3. Recreate the trigger as AFTER INSERT OR UPDATE OF is_active.

-- ============================================================
-- 1. Drop the old INSERT-only trigger
-- ============================================================
DROP TRIGGER IF EXISTS trg_announcement_push ON public.announcements;

-- ============================================================
-- 2. Replace trigger function with UPDATE-aware guard
--    (CREATE OR REPLACE — replaces the version from 013)
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_announcement_push()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed when the announcement is (or becomes) active.
  -- For INSERT: fire whenever is_active = true.
  -- For UPDATE: fire only when transitioning from false → true to avoid
  --             re-sending on unrelated column changes.
  IF NEW.is_active = true
     AND (TG_OP = 'INSERT' OR OLD.is_active = false)
  THEN
    PERFORM public.notify_push_event(
      'announcement:' || NEW.id::text,
      'announcement',
      jsonb_build_object(
        'type',            'announcement',
        'announcement_id', NEW.id,
        'title',           NEW.title,
        'message',         NEW.message,
        'broadcast',       true
      )
    );

    -- Only invoke Edge Function when the dedup insert succeeded (FOUND = true).
    IF FOUND THEN
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
-- 3. Recreate trigger to fire on INSERT OR UPDATE OF is_active
-- ============================================================
CREATE TRIGGER trg_announcement_push
  AFTER INSERT OR UPDATE OF is_active ON public.announcements
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_announcement_push();
