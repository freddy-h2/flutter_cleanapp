-- Add color column to profiles table for user calendar colors
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS color bigint;
