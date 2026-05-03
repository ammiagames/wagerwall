-- 004_decouple_content.sql
-- Move CBT module/lesson content out of the database and into the app binary.
--
-- After this migration:
--   * cbt_modules and cbt_lessons no longer exist (content lives in
--     Wagerwall/Wagerwall/Content/*.swift, see CONTENT_ARCHITECTURE.md).
--   * user_lesson_progress.lesson_id holds an opaque slug (e.g.
--     'lesson-gamblers-fallacy') instead of a UUID FK into cbt_lessons.
--
-- Existing rows in user_lesson_progress that referenced the old UUID lesson
-- IDs become orphaned (their slug equivalents won't match anything in
-- AppContent). The app skips orphaned IDs on read; never reuse an ID.

-- 1. user_lesson_progress: drop FK + change lesson_id type to TEXT
ALTER TABLE public.user_lesson_progress
    DROP CONSTRAINT IF EXISTS user_lesson_progress_lesson_id_fkey;

-- The unique constraint on (user_id, lesson_id) survives the column type change.
ALTER TABLE public.user_lesson_progress
    ALTER COLUMN lesson_id TYPE TEXT USING lesson_id::text;

-- 2. Drop the now-unused content tables (their RLS policies drop with them)
DROP TABLE IF EXISTS public.cbt_lessons;
DROP TABLE IF EXISTS public.cbt_modules;
