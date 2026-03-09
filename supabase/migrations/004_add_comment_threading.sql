-- Add sender_id for tracking who sent the comment (nullable = anonymous)
ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Add parent_id for reply threading (nullable = top-level comment)
ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE;

-- Index for efficient reply lookups
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON public.comments(parent_id);

-- Index for efficient sender lookups
CREATE INDEX IF NOT EXISTS idx_comments_sender_id ON public.comments(sender_id);

-- Allow users to delete their own comments (for cleanup)
CREATE POLICY "Users can delete own comments"
  ON public.comments FOR DELETE
  TO authenticated
  USING (sender_id = auth.uid());
