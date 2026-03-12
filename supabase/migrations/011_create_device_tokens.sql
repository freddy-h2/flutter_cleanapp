-- ============================================================
-- Migration 011: Create device_tokens table with RLS policies
-- ============================================================

-- ============================================================
-- 1. Create device_tokens table
-- ============================================================
CREATE TABLE public.device_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. UNIQUE constraint on (user_id, token) to support UPSERT
-- ============================================================
ALTER TABLE public.device_tokens
  ADD CONSTRAINT device_tokens_user_id_token_key UNIQUE (user_id, token);

-- ============================================================
-- 3. Index on (is_active, user_id) for efficient push lookups
-- ============================================================
CREATE INDEX idx_device_tokens_is_active_user_id
  ON public.device_tokens (is_active, user_id);

-- ============================================================
-- 4. updated_at trigger (uses shared function from 001_init.sql)
-- ============================================================
CREATE TRIGGER set_device_tokens_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- 5. Enable Row Level Security
-- ============================================================
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 6. RLS Policies
-- ============================================================

-- Users can SELECT their own tokens
CREATE POLICY device_tokens_select_own
  ON public.device_tokens FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can INSERT tokens for themselves
CREATE POLICY device_tokens_insert_own
  ON public.device_tokens FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can UPDATE their own tokens
CREATE POLICY device_tokens_update_own
  ON public.device_tokens FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can DELETE their own tokens
CREATE POLICY device_tokens_delete_own
  ON public.device_tokens FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- service_role can SELECT all tokens (for Edge Functions)
CREATE POLICY device_tokens_select_all_service_role
  ON public.device_tokens FOR SELECT
  TO service_role
  USING (true);

-- ============================================================
-- 7. Enable Realtime
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.device_tokens;
