-- Migration: 003_create_extension_requests.sql
-- Description: Create extension_requests table for the prórroga system

-- ============================================================
-- extension_requests table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.extension_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  next_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE public.extension_requests ENABLE ROW LEVEL SECURITY;

-- SELECT: authenticated users can see requests where they are requester, next_user, or admin
CREATE POLICY "Users can view their own extension requests"
  ON public.extension_requests FOR SELECT
  TO authenticated
  USING (
    requester_id = auth.uid()
    OR next_user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- INSERT: authenticated users can insert rows where requester_id = auth.uid()
CREATE POLICY "Users can create extension requests as requester"
  ON public.extension_requests FOR INSERT
  TO authenticated
  WITH CHECK (requester_id = auth.uid());

-- UPDATE: next_user_id (acceptor/rejector) or admin can update
CREATE POLICY "Next user or admin can update extension requests"
  ON public.extension_requests FOR UPDATE
  TO authenticated
  USING (
    next_user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- DELETE: only admins can delete
CREATE POLICY "Only admins can delete extension requests"
  ON public.extension_requests FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_extension_requests_schedule_id
  ON public.extension_requests (schedule_id);

CREATE INDEX IF NOT EXISTS idx_extension_requests_status
  ON public.extension_requests (status);
