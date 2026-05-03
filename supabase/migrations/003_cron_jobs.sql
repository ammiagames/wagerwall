-- 003_cron_jobs.sql
-- Set up pg_cron schedules for automated tasks.
-- NOTE: pg_cron is available on Supabase Pro plan and above.
-- On the free tier, these can be triggered manually or via external cron (e.g., GitHub Actions).

-- Add unique constraint on device_heartbeats for upsert support
ALTER TABLE public.device_heartbeats
    ADD CONSTRAINT device_heartbeats_user_device_unique UNIQUE (user_id, device_id);

-- Enable pg_cron extension (available on Supabase hosted)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Check heartbeats every 15 minutes
-- Calls the check-heartbeats edge function to detect stale devices
-- SELECT cron.schedule(
--     'check-stale-heartbeats',
--     '*/15 * * * *',
--     $$
--     SELECT net.http_post(
--         url := current_setting('app.settings.supabase_url') || '/functions/v1/check-heartbeats',
--         headers := jsonb_build_object(
--             'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
--             'Content-Type', 'application/json'
--         ),
--         body := '{}'::jsonb
--     );
--     $$
-- );

-- Daily streak update at midnight UTC
-- Calls the daily-streak-update edge function to increment streaks and money saved
-- SELECT cron.schedule(
--     'daily-streak-update',
--     '0 0 * * *',
--     $$
--     SELECT net.http_post(
--         url := current_setting('app.settings.supabase_url') || '/functions/v1/daily-streak-update',
--         headers := jsonb_build_object(
--             'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
--             'Content-Type', 'application/json'
--         ),
--         body := '{}'::jsonb
--     );
--     $$
-- );

-- Process disable requests every 5 minutes
-- Checks for expired cooling-off periods and processes them
-- SELECT cron.schedule(
--     'process-disable-requests',
--     '*/5 * * * *',
--     $$
--     SELECT net.http_post(
--         url := current_setting('app.settings.supabase_url') || '/functions/v1/process-disable-request',
--         headers := jsonb_build_object(
--             'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
--             'Content-Type', 'application/json'
--         ),
--         body := '{}'::jsonb
--     );
--     $$
-- );
