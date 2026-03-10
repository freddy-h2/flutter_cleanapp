-- ============================================================
-- 7. RPC: accept_extension_swap
-- Performs the prórroga acceptance + schedule swap atomically.
-- Runs as SECURITY DEFINER to bypass RLS on schedules.
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_extension_swap(
  p_request_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request RECORD;
  v_anchor RECORD;
  v_requester_ids UUID[];
  v_next_anchor_id UUID;
  v_next_ids UUID[];
  v_period_days INT := 3;
  v_schedule RECORD;
  v_count INT;
BEGIN
  -- 1. Fetch and validate the request.
  SELECT * INTO v_request
  FROM extension_requests
  WHERE id = p_request_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Extension request not found or not pending: %', p_request_id;
  END IF;

  -- 2. Mark the request as accepted.
  UPDATE extension_requests
  SET status = 'accepted', resolved_at = now()
  WHERE id = p_request_id;

  -- 3. Find the anchor schedule.
  SELECT * INTO v_anchor
  FROM schedules
  WHERE id = v_request.schedule_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Anchor schedule not found: %', v_request.schedule_id;
  END IF;

  -- 4. Find the requester's period (up to v_period_days consecutive
  --    same-user schedules around the anchor).
  --    We collect IDs by walking backward and forward from the anchor
  --    in date order, stopping on user change, date gap > 1, or maxSize.
  WITH ordered AS (
    SELECT id, user_id, date,
           ROW_NUMBER() OVER (ORDER BY date) AS rn
    FROM schedules
    ORDER BY date
  ),
  anchor_rn AS (
    SELECT rn FROM ordered WHERE id = v_anchor.id
  ),
  -- Walk backward from anchor
  backward AS (
    SELECT o.id, o.date, o.rn
    FROM ordered o, anchor_rn a
    WHERE o.rn < a.rn
      AND o.user_id = v_anchor.user_id
      AND o.date >= v_anchor.date - (v_period_days - 1)
    ORDER BY o.rn DESC
  ),
  -- Walk forward from anchor
  forward AS (
    SELECT o.id, o.date, o.rn
    FROM ordered o, anchor_rn a
    WHERE o.rn > a.rn
      AND o.user_id = v_anchor.user_id
      AND o.date <= v_anchor.date + (v_period_days - 1)
    ORDER BY o.rn ASC
  )
  SELECT ARRAY_AGG(id ORDER BY date) INTO v_requester_ids
  FROM (
    -- Backward: only consecutive (gap <= 1 day)
    SELECT id, date FROM (
      SELECT b.id, b.date,
             LEAD(b.date) OVER (ORDER BY b.rn) AS next_date
      FROM backward b
    ) sub
    WHERE next_date IS NULL OR (next_date - date) <= 1
    UNION ALL
    -- Anchor itself
    SELECT v_anchor.id, v_anchor.date
    UNION ALL
    -- Forward: only consecutive (gap <= 1 day)
    SELECT id, date FROM (
      SELECT f.id, f.date,
             LAG(f.date) OVER (ORDER BY f.rn) AS prev_date
      FROM forward f
    ) sub
    WHERE prev_date IS NULL OR (date - prev_date) <= 1
  ) combined;

  -- Cap to v_period_days entries (take first N by date).
  IF array_length(v_requester_ids, 1) > v_period_days THEN
    v_requester_ids := v_requester_ids[1:v_period_days];
  END IF;

  -- 5. Find the next user's period anchor: first schedule belonging to
  --    nextUserId with date after the requester's period end.
  SELECT id INTO v_next_anchor_id
  FROM schedules
  WHERE user_id = v_request.next_user_id
    AND date > (SELECT MAX(date) FROM schedules WHERE id = ANY(v_requester_ids))
  ORDER BY date
  LIMIT 1;

  -- 6. Find the next user's period (same walk logic, capped).
  IF v_next_anchor_id IS NOT NULL THEN
    WITH anchor_info AS (
      SELECT date AS anchor_date FROM schedules WHERE id = v_next_anchor_id
    ),
    ordered AS (
      SELECT id, user_id, date,
             ROW_NUMBER() OVER (ORDER BY date) AS rn
      FROM schedules
      ORDER BY date
    ),
    anchor_rn AS (
      SELECT rn FROM ordered WHERE id = v_next_anchor_id
    ),
    forward AS (
      SELECT o.id, o.date, o.rn
      FROM ordered o, anchor_rn a, anchor_info ai
      WHERE o.rn > a.rn
        AND o.user_id = (SELECT user_id FROM schedules WHERE id = v_next_anchor_id)
        AND o.date <= ai.anchor_date + (v_period_days - 1)
      ORDER BY o.rn ASC
    )
    SELECT ARRAY_AGG(id ORDER BY date) INTO v_next_ids
    FROM (
      SELECT v_next_anchor_id AS id, (SELECT date FROM schedules WHERE id = v_next_anchor_id) AS date
      UNION ALL
      SELECT id, date FROM (
        SELECT f.id, f.date,
               LAG(f.date) OVER (ORDER BY f.rn) AS prev_date
        FROM forward f
      ) sub
      WHERE prev_date IS NULL OR (date - prev_date) <= 1
    ) combined;

    IF array_length(v_next_ids, 1) > v_period_days THEN
      v_next_ids := v_next_ids[1:v_period_days];
    END IF;
  END IF;

  -- 7. Swap: set requester's period to nextUserId.
  UPDATE schedules
  SET user_id = v_request.next_user_id
  WHERE id = ANY(v_requester_ids);

  -- 8. Swap: set next user's period to requesterId.
  IF v_next_ids IS NOT NULL AND array_length(v_next_ids, 1) > 0 THEN
    UPDATE schedules
    SET user_id = v_request.requester_id
    WHERE id = ANY(v_next_ids);
  END IF;
END;
$$;

-- Grant execute to authenticated users.
GRANT EXECUTE ON FUNCTION public.accept_extension_swap(UUID) TO authenticated;
