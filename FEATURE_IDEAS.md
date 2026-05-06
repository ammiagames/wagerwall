# Feature Ideas

Running backlog of potential features for WagerWall. **Not committed scope** — ideas to revisit when planning real work. For canonical implementation status, see [`CLAUDE.md`](CLAUDE.md).

Each idea lists where it came from, current state in WagerWall, and rough notes on what building it would entail.

---

## Sources of inspiration

- **Quittr** — successful porn-quitting app. Recovery-app pattern is highly transferable to gambling.

---

## Ideas

### 1. Journey statistics with percentile framing

**From**: Quittr
**Current state**: Not built. `ProgressTabView` exists but charting depth is unverified.

**Notes**:
- Visualize streak history, urge frequency, mood/urge correlation, blocked-attempt count over time.
- "Percentile" framing — *"you're in the top 20% of users by streak length"* — leverages social proof and competitive drive without exposing other users' data.
- Computing percentile live across all users is expensive. Cheaper: a daily Edge Function snapshots aggregate streak distribution into a small `streak_percentiles` table (or a JSONB column), and the client interpolates.
- Watch out for the "leaderboard effect" turning recovery into a game in unhealthy ways. Frame as solidarity, not competition.

### 2. Community / social posts

**From**: Quittr
**Current state**: Not built. Already listed as "Group support" in [`PROJECT.md`](PROJECT.md) § 9.2.

**Notes**:
- Anonymous, optionally tied to recovery stage or streak band ("week 1", "month 3+").
- Heavy lift — needs moderation, abuse reporting, profanity filtering, push fanout, content policy.
- Lower-friction starting point: a *milestone feed* (auto-posted "User reached 30 days") with reactions but no free-form posting. Free-form text comes later once moderation is in place.
- Realtime is supported by Supabase out of the box (WebSockets). Storage and indexing of posts is the harder part.

### 3. Active-streak home page

**From**: Quittr
**Current state**: Already built. `DashboardView` shows streak counter wired to `UserStreak`.

**Notes**:
- Could borrow Quittr's visual treatment: large hero number, breakdown into days/hours/minutes/seconds, animated milestones at 1/3/7/14/30/90/365 days.
- Pair with the pledge feature (#5) — show pledge text under the streak as a constant reminder.

### 4. Daily journaling

**From**: Quittr
**Current state**: Partial. Per-lesson journal sections exist (`Section.journal`, persisted to `user_lesson_progress.exercise_data`). No freeform daily journal.

**Notes**:
- Quittr-style: one entry per day, optional rotating prompts, browseable history.
- Schema sketch: `journal_entries (id, user_id, body, prompt_id, mood_score, created_at)`. New migration; doesn't touch existing CBT progress tables.
- Sensitive content — encrypt client-side before persisting (see [`PROJECT.md`](PROJECT.md) § 10.2 on E2E for journals).
- Optional: surface a journal prompt as a daily push notification once `send-push` is finished.

### 5. Pledge / commitment

**From**: Quittr
**Current state**: Not built. `user_profiles.quit_date` exists but no UX around it.

**Notes**:
- One-tap action during onboarding or anytime: *"I pledge not to gamble for [X days / forever]"*.
- Display the pledge prominently on the dashboard. Surface it inside the urge-logging flow as a reminder.
- Schema: extend `user_profiles` with `pledge_text TEXT`, `pledge_made_at TIMESTAMPTZ`, optional `pledge_duration_days INT`. Reuse `quit_date` for the start.
- Aligns with the existing accountability-partner system — could optionally co-sign a pledge with a partner.

### 6. Reset streak (honest relapse logging)

**From**: Quittr
**Current state**: Not explicitly built (needs verification — search for streak-mutation logic in `StreakService` / `UserStreakRepository`).

**Notes**:
- Critical that this is *not* shame-gated. Honest self-reset is core to recovery.
- UX: tap "I gambled" → brief, judgement-free reflection prompt → reset `current_streak_days` to 0; log the relapse.
- `user_streaks.longest_streak_days` already separate, so resets preserve the all-time best.
- Consider a new `relapse_logs` table (`user_id`, `relapsed_at`, `trigger_category`, `notes`, `previous_streak_days`) for trend analysis. Reuses urge_logs trigger taxonomy.
- Should notify accountability partner (with user's prior consent) — wires into the existing `notify-partner` Edge Function.

### 7. Urge tracking

**From**: Quittr
**Current state**: Already built. `LogUrgeView` + `UrgeLogViewModel` + `urge_logs` table with intensity, trigger category, outcome.

**Notes**:
- Could borrow Quittr UX touches: a *"this urge will pass"* timer (urges typically peak in 15–20 min), and a post-urge reflection prompt that gets attached to the log.
- Tie outcome `'resisted'` directly to a small streak-of-resistances counter, distinct from the abstinence streak.

---

## How to use this doc

- Add new ideas under `## Ideas` with the same shape (source, current state, notes).
- When an idea graduates to committed work, move it to a phase in [`CLAUDE.md`](CLAUDE.md) and remove (or strikethrough) the entry here.
- Keep "current state" lines accurate — they're the main thing that prevents re-debating settled work.
