-- WagerWall Initial Schema
-- Creates all core tables, RLS policies, and triggers

-- ============================================================
-- Extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Tables
-- ============================================================

-- Users (extends Supabase auth.users)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    avatar_url TEXT,
    gambling_severity TEXT CHECK (gambling_severity IN ('low', 'moderate', 'high', 'severe')),
    assessment_score INTEGER,
    quit_date TIMESTAMPTZ,
    daily_gambling_spend DECIMAL(10,2),
    timezone TEXT DEFAULT 'America/New_York',
    onboarding_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User streaks
CREATE TABLE public.user_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    current_streak_days INTEGER DEFAULT 0,
    longest_streak_days INTEGER DEFAULT 0,
    last_check_in DATE,
    money_saved_estimate DECIMAL(10,2) DEFAULT 0,
    UNIQUE(user_id)
);

-- Accountability partners
CREATE TABLE public.accountability_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    partner_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    partner_email TEXT,
    partner_phone TEXT,
    lock_code_hash TEXT,
    status TEXT CHECK (status IN ('invited', 'active', 'removed')) DEFAULT 'invited',
    invited_at TIMESTAMPTZ DEFAULT NOW(),
    activated_at TIMESTAMPTZ
);

-- Device heartbeats (for deletion detection)
CREATE TABLE public.device_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    apns_token TEXT,
    last_heartbeat TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- CBT module definitions
CREATE TABLE public.cbt_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER NOT NULL,
    estimated_minutes INTEGER,
    icon_name TEXT,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- CBT lesson definitions
CREATE TABLE public.cbt_lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID REFERENCES public.cbt_modules(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    content JSONB NOT NULL,
    lesson_type TEXT CHECK (lesson_type IN ('reading', 'exercise', 'quiz', 'journal', 'audio')),
    sort_order INTEGER NOT NULL,
    estimated_minutes INTEGER,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User lesson progress
CREATE TABLE public.user_lesson_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES public.cbt_lessons(id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('not_started', 'in_progress', 'completed')) DEFAULT 'not_started',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    exercise_data JSONB,
    UNIQUE(user_id, lesson_id)
);

-- Urge logs
CREATE TABLE public.urge_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    intensity INTEGER CHECK (intensity BETWEEN 1 AND 10),
    trigger_category TEXT,
    trigger_notes TEXT,
    coping_strategy_used TEXT,
    outcome TEXT CHECK (outcome IN ('resisted', 'gave_in', 'used_panic_button')),
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mood check-ins
CREATE TABLE public.mood_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    mood_score INTEGER CHECK (mood_score BETWEEN 1 AND 5),
    notes TEXT,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- Blocked attempt logs (synced from device)
CREATE TABLE public.blocked_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    blocked_item_type TEXT CHECK (blocked_item_type IN ('app', 'website')),
    blocked_category TEXT,
    attempted_at TIMESTAMPTZ DEFAULT NOW()
);

-- Protection disable requests (cooling-off)
CREATE TABLE public.disable_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    cooloff_ends_at TIMESTAMPTZ NOT NULL,
    partner_approved BOOLEAN DEFAULT FALSE,
    partner_approved_at TIMESTAMPTZ,
    status TEXT CHECK (status IN ('pending', 'approved', 'expired', 'cancelled')) DEFAULT 'pending'
);

-- Push notification tokens
CREATE TABLE public.push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- ============================================================
-- Row Level Security
-- ============================================================

-- user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- user_streaks
ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own streaks"
    ON public.user_streaks FOR ALL
    USING (auth.uid() = user_id);

-- accountability_partners
ALTER TABLE public.accountability_partners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own partnerships"
    ON public.accountability_partners FOR ALL
    USING (auth.uid() = user_id OR auth.uid() = partner_user_id);

-- device_heartbeats
ALTER TABLE public.device_heartbeats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own heartbeats"
    ON public.device_heartbeats FOR ALL
    USING (auth.uid() = user_id);

-- cbt_modules (read-only for authenticated users)
ALTER TABLE public.cbt_modules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read published modules"
    ON public.cbt_modules FOR SELECT
    USING (auth.role() = 'authenticated' AND is_published = TRUE);

-- cbt_lessons (read-only for authenticated users)
ALTER TABLE public.cbt_lessons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read published lessons"
    ON public.cbt_lessons FOR SELECT
    USING (auth.role() = 'authenticated' AND is_published = TRUE);

-- user_lesson_progress
ALTER TABLE public.user_lesson_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own lesson progress"
    ON public.user_lesson_progress FOR ALL
    USING (auth.uid() = user_id);

-- urge_logs
ALTER TABLE public.urge_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own urge logs"
    ON public.urge_logs FOR ALL
    USING (auth.uid() = user_id);

-- mood_logs
ALTER TABLE public.mood_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own mood logs"
    ON public.mood_logs FOR ALL
    USING (auth.uid() = user_id);

-- blocked_attempts
ALTER TABLE public.blocked_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own blocked attempts"
    ON public.blocked_attempts FOR ALL
    USING (auth.uid() = user_id);

-- disable_requests
ALTER TABLE public.disable_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own disable requests"
    ON public.disable_requests FOR ALL
    USING (auth.uid() = user_id);

-- push_tokens
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own push tokens"
    ON public.push_tokens FOR ALL
    USING (auth.uid() = user_id);

-- ============================================================
-- Functions & Triggers
-- ============================================================

-- Auto-create user_profile and user_streaks on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, display_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    INSERT INTO public.user_streaks (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-update updated_at on user_profiles
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_user_profile_updated
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
