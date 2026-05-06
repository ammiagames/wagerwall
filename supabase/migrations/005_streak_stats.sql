-- WagerWall Streak Stats
-- Adds historical streak tracking + an aggregate-only RPC powering the
-- Profile tab's longest / average / percentile cards.

-- ============================================================
-- streak_history: one row per completed streak
-- ============================================================

CREATE TABLE public.streak_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    length_days INTEGER NOT NULL CHECK (length_days > 0),
    ended_at DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX streak_history_user_id_idx ON public.streak_history(user_id);

ALTER TABLE public.streak_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own streak history"
    ON public.streak_history FOR SELECT
    USING (auth.uid() = user_id);

-- ============================================================
-- Trigger: archive a streak when it resets to zero
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_streak_reset()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.current_streak_days > 0 AND NEW.current_streak_days = 0 THEN
        INSERT INTO public.streak_history (user_id, length_days, ended_at)
        VALUES (
            OLD.user_id,
            OLD.current_streak_days,
            COALESCE(OLD.last_check_in, CURRENT_DATE)
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_streak_reset
    AFTER UPDATE OF current_streak_days ON public.user_streaks
    FOR EACH ROW EXECUTE FUNCTION public.log_streak_reset();

-- ============================================================
-- RPC: aggregate stats for the Profile tab
--
-- SECURITY DEFINER lets the function read other users' user_streaks rows
-- to compute the percentile rank. We never return identifiable data —
-- only aggregates and counts — and we still gate execution on the caller
-- being the same user as p_user_id.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_user_streak_stats(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current INTEGER;
    v_longest INTEGER;
    v_history_count INTEGER;
    v_history_sum INTEGER;
    v_total_streaks INTEGER;
    v_average NUMERIC;
    v_total_users INTEGER;
    v_users_below INTEGER;
    v_percentile NUMERIC;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    SELECT
        COALESCE(current_streak_days, 0),
        COALESCE(longest_streak_days, 0)
    INTO v_current, v_longest
    FROM public.user_streaks
    WHERE user_id = p_user_id;

    SELECT
        COUNT(*),
        COALESCE(SUM(length_days), 0)
    INTO v_history_count, v_history_sum
    FROM public.streak_history
    WHERE user_id = p_user_id;

    -- The current streak (if any) counts as an in-progress run.
    IF v_current > 0 THEN
        v_total_streaks := v_history_count + 1;
        v_average := (v_history_sum + v_current)::NUMERIC / v_total_streaks;
    ELSIF v_history_count > 0 THEN
        v_total_streaks := v_history_count;
        v_average := v_history_sum::NUMERIC / v_history_count;
    ELSE
        v_total_streaks := 0;
        v_average := 0;
    END IF;

    SELECT COUNT(*) INTO v_total_users FROM public.user_streaks;

    IF v_total_users > 1 THEN
        SELECT COUNT(*) INTO v_users_below
        FROM public.user_streaks
        WHERE COALESCE(current_streak_days, 0) < v_current;
        v_percentile := (v_users_below::NUMERIC / v_total_users::NUMERIC) * 100.0;
    ELSE
        v_percentile := 100.0;
    END IF;

    RETURN json_build_object(
        'current_streak_days', v_current,
        'longest_streak_days', v_longest,
        'average_streak_days', ROUND(v_average, 1),
        'total_streaks', v_total_streaks,
        'percentile', ROUND(v_percentile, 1),
        'total_users', v_total_users
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_streak_stats(UUID) TO authenticated;
