-- Enable Supabase Realtime for tables used by RealtimeService.
-- Run this once in the Supabase SQL editor (or apply via migration).
ALTER PUBLICATION supabase_realtime ADD TABLE schedules;
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE comments;
ALTER PUBLICATION supabase_realtime ADD TABLE extension_requests;
