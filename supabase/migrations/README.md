# Migrations

Append-only SQL. Numbered `NNN_description.sql`. `supabase db reset` drops the database and reruns everything in order; production deploys via `supabase db push`.

> **Never edit a previously-released migration.** Add a new numbered file instead.

---

## Files

| # | File | Status | What it does |
|---|---|---|---|
| 001 | `001_initial_schema.sql` | ✅ stable | Creates 14 tables, RLS policies, signup trigger, updated_at trigger |
| 002 | `002_cbt_content.sql` | 🟡 no-op | Previously seeded CBT content; now empty (content moved to app binary in 004) |
| 003 | `003_cron_jobs.sql` | ⏸ commented out | Three pg_cron schedules — requires Supabase Pro tier |
| 004 | `004_decouple_content.sql` | ✅ stable | Drops `cbt_modules` and `cbt_lessons`; converts `user_lesson_progress.lesson_id` UUID → TEXT |

After 004, the active table count is **12** (was 14 in 001).

---

## `001_initial_schema.sql`

### Extensions
- `uuid-ossp`

### Tables (14 created here, 2 dropped later in 004)

| Table | Purpose | Notable columns |
|---|---|---|
| `user_profiles` | Extends `auth.users` | `gambling_severity` (low/moderate/high/severe), `assessment_score`, `quit_date`, `daily_gambling_spend`, `onboarding_completed` |
| `user_streaks` | Streak counter | `current_streak_days`, `longest_streak_days`, `last_check_in` (DATE), `money_saved_estimate` |
| `accountability_partners` | Partner relationships | `partner_email`, `partner_phone`, `lock_code_hash` (bcrypt), `status` (invited/active/removed) |
| `device_heartbeats` | Deletion detection | `device_id`, `apns_token`, `last_heartbeat`, `is_active` |
| `cbt_modules` | (dropped in 004) | — |
| `cbt_lessons` | (dropped in 004) | — |
| `user_lesson_progress` | Per-user lesson state | `lesson_id` (UUID, → TEXT in 004), `status` (not_started/in_progress/completed), `exercise_data` (JSONB) |
| `urge_logs` | Logged urges | `intensity` 1–10, `trigger_category`, `outcome` (resisted/gave_in/used_panic_button) |
| `mood_logs` | Daily mood | `mood_score` 1–5 |
| `blocked_attempts` | Blocked app/site attempts | `blocked_item_type` (app/website), `blocked_category` |
| `disable_requests` | Cooling-off disable flow | `cooloff_ends_at`, `partner_approved`, `status` (pending/approved/expired/cancelled) |
| `push_tokens` | APNs tokens | `token`, `platform = 'ios'`, UNIQUE(user_id, token) |

### RLS

Every table has RLS enabled. Default pattern: `auth.uid() = user_id`. Exceptions:

- `user_profiles` — uses `auth.uid() = id` (id is the FK to auth.users).
- `accountability_partners` — `auth.uid() = user_id OR auth.uid() = partner_user_id` (so the partner can see the relationship too).
- `cbt_modules` / `cbt_lessons` — read-only for any authenticated user where `is_published = TRUE` (these tables are dropped in 004 so this no longer applies).

### Triggers

- **`handle_new_user()`** (lines 253–265) — fires `AFTER INSERT ON auth.users`. Creates a row in `user_profiles` and `user_streaks` so every signed-up user has those records ready. iOS code assumes both rows exist.
- **`handle_updated_at()`** (lines 272–278) — `BEFORE UPDATE ON user_profiles`, sets `updated_at = NOW()`.

---

## `002_cbt_content.sql` — no-op

```sql
-- DEPRECATED — content moved to the app binary in migration 004_decouple_content.sql
-- This migration is intentionally empty. Kept for reproducibility.
```

CBT modules and lessons used to be seeded here. After the architecture change documented in `CONTENT_ARCHITECTURE.md`, content is bundled in `Wagerwall/Wagerwall/Content/*.swift`. The file is kept (not deleted) so the migration history stays continuous.

---

## `003_cron_jobs.sql` — commented out

All three schedules are commented out. Supabase free tier doesn't include `pg_cron`; uncomment after upgrading to Pro (or trigger the functions from an external scheduler).

| Schedule | Cron | Hits |
|---|---|---|
| `check-stale-heartbeats` | `*/15 * * * *` (every 15 min) | `/functions/v1/check-heartbeats` |
| `daily-streak-update` | `0 0 * * *` (midnight UTC) | `/functions/v1/daily-streak-update` |
| `process-disable-requests` | `*/5 * * * *` (every 5 min) | `/functions/v1/process-disable-request` |

This file also adds `UNIQUE(user_id, device_id)` on `device_heartbeats` so heartbeat upserts work.

---

## `004_decouple_content.sql`

```sql
ALTER TABLE user_lesson_progress
    DROP CONSTRAINT user_lesson_progress_lesson_id_fkey;
ALTER TABLE user_lesson_progress
    ALTER COLUMN lesson_id TYPE TEXT USING lesson_id::TEXT;

DROP TABLE IF EXISTS cbt_lessons CASCADE;
DROP TABLE IF EXISTS cbt_modules CASCADE;
```

Effect:
- `user_lesson_progress.lesson_id` is now an opaque slug like `"lesson-gamblers-fallacy"` — must match an entry in `Wagerwall/Wagerwall/Content/AppContent.swift`. No FK; orphaned slugs (rows referencing a deleted lesson ID) are skipped by the app.
- `cbt_modules` and `cbt_lessons` are gone. RLS policies attached to them drop automatically via CASCADE.

⚠️ Old UUID values in `user_lesson_progress.lesson_id` cast to TEXT cleanly, but those UUIDs no longer match any lesson slug — those rows are orphaned. Acceptable since this was pre-launch.

---

## Adding a new migration

1. Pick the next number (`005_`, `006_`, …). Use snake_case description.
2. Create the file under `supabase/migrations/`.
3. **Append-only.** Add tables, columns, indexes, policies, triggers — never `DROP` something a previous migration created without thinking through downstream effects.
4. Test locally:
   ```bash
   supabase db reset    # nukes the local DB and re-runs everything
   ```
5. If you need to seed local data only, put it in `seed.sql` (referenced from `config.toml:65`) — currently absent. Don't seed via migrations; that runs in production too.
6. Push to remote:
   ```bash
   supabase db push
   ```

---

## Things that need future migrations

From `CONTENT_ARCHITECTURE.md`:
- **`005_question_bank.sql`** (sketched, not written): adds `question_attempts` and `user_question_state` for the spaced-repetition review system.

From `CLAUDE.md`:
- An Apple Sign-In migration may be unnecessary (Supabase auth handles it via dashboard config), but if any client-side state needs Apple-specific columns, it goes here.
