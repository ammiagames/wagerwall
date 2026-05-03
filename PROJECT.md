# WagerWall — iOS App to Help Users Quit Gambling

## Table of Contents

1. [Overview](#1-overview)
2. [Key Recommendations & Decisions](#2-key-recommendations--decisions)
3. [Tech Stack](#3-tech-stack)
4. [Service Setup Requirements](#4-service-setup-requirements)
5. [Core Features](#5-core-features)
6. [Database Schema (Supabase)](#6-database-schema-supabase)
7. [App Architecture](#7-app-architecture)
8. [Implementation Phases](#8-implementation-phases)
9. [Future Services & Features](#9-future-services--features)
10. [App Store & Compliance](#10-app-store--compliance)
11. [Open Questions](#11-open-questions)

---

## 1. Overview

WagerWall is an iOS app that helps users overcome gambling addiction through:

- **CBT-based learning modules** — structured cognitive behavioral therapy content
- **App & website blocking** — prevents access to gambling apps and sites
- **Deletion resistance** — makes it difficult to impulsively remove the app
- **Accountability systems** — social support mechanisms to maintain commitment

---

## 2. Key Recommendations & Decisions

### 2.1 Blocking Strategy: Hybrid Approach (Screen Time API + NetworkExtension Content Filter)

**Recommendation: Use a hybrid of Apple's Screen Time API for app blocking and a `NetworkExtension` content filter for website blocking.** This mirrors how the most effective anti-gambling apps (Gamban, BetBlocker) operate while adding superior app-level blocking that those apps lack.

#### Why hybrid?

Screen Time API alone has a critical limitation: **if the user deletes WagerWall, FamilyControls authorization is revoked and all blocks are cleared.** A `NetworkExtension` content filter installed via a password-protected configuration profile survives app deletion.

#### Comparison of approaches

| Factor | Screen Time API | NetworkExtension Content Filter | Hybrid (both) |
|--------|----------------|--------------------------------|----------------|
| App blocking | Blocks apps at OS level | Cannot block apps | Apps blocked |
| Website blocking | Safari only (`WebContentSettings`) | All browsers (system-level DNS/content filter) | All browsers |
| Survives app deletion | **No** — blocks cleared on delete | **Yes** — config profile persists | Websites still blocked |
| Bypass difficulty | Must revoke FamilyControls auth | Must remove password-protected profile | Both layers must be defeated |
| Battery impact | Minimal | Low (DNS-level filtering, not full VPN tunnel) | Low |
| User VPN conflict | None | Possible (if using VPN-style filter) | Depends on filter type |
| Apple approval | Apple-sanctioned | Requires Network Extension entitlement | Both entitlements needed |

#### Implementation layers

| Layer | Mechanism | What it blocks | Survives app deletion? |
|-------|-----------|---------------|----------------------|
| 1. App blocking | `ManagedSettings` (Screen Time API) | Gambling apps by category + individual selection | No |
| 2. Website blocking | `NEFilterDataProvider` / `NEDNSProxyProvider` (NetworkExtension) | Gambling websites across all browsers | **Yes** |
| 3. Profile protection | Password-protected `.mobileconfig` configuration profile | N/A — protects Layer 2 from removal | **Yes** (partner holds password) |
| 4. Deletion detection | Heartbeat monitoring (Supabase server-side) | N/A — alerts partner on app deletion | **Yes** |

#### Key frameworks

- `FamilyControls` — authorization to manage Screen Time settings on the device
- `ManagedSettings` — apply restrictions (block apps, shield apps)
- `DeviceActivity` — schedule monitoring windows and respond to activity events
- `NetworkExtension` — system-level content filter for website blocking across all browsers

**Requires**: "Family Controls" and "Network Extension" capability entitlements from Apple (must apply via Apple Developer portal — see Section 4.1).

### 2.2 Deletion Resistance Strategy

iOS does not allow third-party apps to prevent their own deletion. However, apps like Gamban achieve effective deletion resistance by **separating the blocking mechanism from the app itself** — the app is just a management UI, while the actual blocking lives in a system-level configuration profile.

WagerWall uses this same principle combined with layered deterrence:

1. **NetworkExtension content filter in a password-protected config profile** — Website blocking persists after app deletion. The configuration profile requires a removal password held by the accountability partner. This is how Gamban and BetBlocker achieve deletion resistance.
2. **Shield overlay via ManagedSettings** — When the user tries to open a blocked app, a WagerWall-branded shield appears instead. This keeps WagerWall embedded in the user's routine.
3. **Accountability partner system** — A trusted contact receives a notification if the user attempts to disable protections or remove the app. The partner holds the config profile removal password and a lock code required to disable app-level blocking.
4. **Heartbeat monitoring** — The app sends periodic heartbeats to Supabase. If heartbeats stop (app deleted), the server notifies the accountability partner and emails the user. Even with the app deleted, website blocking (Layer 1) remains active.
5. **Cooling-off timer** — Disabling protections requires a mandatory 24-48 hour waiting period, preventing impulsive removal during urge spikes.
6. **MDM profile (optional, advanced)** — For users who want maximum protection, offer an optional lightweight MDM profile that prevents app deletion at the OS level. This is the nuclear option and should be clearly communicated to the user.

### 2.3 Supabase — Confirmed Good Choice

Supabase is the right backend for this project. It provides:
- **PostgreSQL database** with Row Level Security (RLS)
- **Auth** with built-in Google OAuth provider (simplifies GCP integration)
- **Edge Functions** (Deno/TypeScript) for server-side logic (heartbeat checker, partner notifications)
- **Realtime** subscriptions for live accountability partner status
- **Storage** for CBT media content (audio, images)
- **Cron jobs** via `pg_cron` for scheduled tasks (heartbeat checks, streak calculations)

No need for a separate backend server.

### 2.4 Google OAuth via Supabase Auth

Supabase Auth has a built-in Google provider. This means:
- You configure the GCP OAuth client credentials **in Supabase dashboard**, not in the app directly
- The iOS app uses the Supabase Auth SDK to trigger the Google sign-in flow
- Supabase handles token exchange, session management, and refresh
- Less GCP-side code; Supabase is the middleman

---

## 3. Tech Stack

### 3.1 iOS App

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Minimum iOS | 17.0 (Screen Time API matured in iOS 16-17) |
| Architecture | MVVM + Repository pattern |
| Networking | Supabase Swift SDK (`supabase-swift`) |
| Auth | Supabase Auth (Google OAuth provider) + Apple Sign-In |
| App Blocking | `FamilyControls`, `ManagedSettings`, `DeviceActivity` |
| Notifications | APNs (Apple Push Notification Service) via Supabase Edge Functions |
| Local Storage | SwiftData (for offline CBT progress caching) |
| Keychain | For storing Supabase session tokens securely |

### 3.2 Backend (Supabase)

| Component | Technology |
|-----------|-----------|
| Database | PostgreSQL 15 (Supabase-managed) |
| Auth | Supabase Auth with Google OAuth + Apple OAuth providers |
| Server Logic | Supabase Edge Functions (Deno/TypeScript) |
| Scheduling | `pg_cron` extension for periodic jobs |
| Realtime | Supabase Realtime (WebSocket subscriptions) |
| Storage | Supabase Storage (CBT audio/images) |
| Push Notifications | Edge Function → APNs (via `apple-push-notification` npm package) |

### 3.3 External Services

| Service | Purpose |
|---------|---------|
| Google Cloud Platform | OAuth 2.0 client credentials for Google Sign-In |
| Apple Developer Program | App distribution, entitlements, APNs certificates |
| RevenueCat (future) | Subscription/in-app purchase management |
| PostHog or Mixpanel (future) | Product analytics |
| Sentry (future) | Crash reporting and error tracking |

---

## 4. Service Setup Requirements

### 4.1 Apple Developer Account

**Cost**: $99/year
**Required for**: Everything — you cannot develop with Screen Time API without this.

Setup steps:
1. Enroll at [developer.apple.com](https://developer.apple.com/programs/enroll/)
2. **Request Family Controls entitlement**: Go to developer.apple.com → Account → Certificates, Identifiers & Profiles → Identifiers → select your App ID → enable "Family Controls" capability. You may need to submit a request form explaining your use case (gambling addiction recovery app). Apple reviews these manually.
3. Create an **APNs Key** (Account → Keys → + → Apple Push Notifications service). Download the `.p8` file — you'll need this for Supabase Edge Functions to send push notifications. Record the Key ID and Team ID.
4. Create App IDs for all targets:
   - `com.wagerwall.app` (main app)
   - `com.wagerwall.app.ShieldConfiguration` (shield UI extension)
   - `com.wagerwall.app.ShieldAction` (shield action extension)
   - `com.wagerwall.app.DeviceActivityMonitor` (activity monitor extension)
5. Enable capabilities on the main App ID:
   - Family Controls
   - Push Notifications
   - Associated Domains (for universal links / deep links from emails)
   - App Groups (for sharing data between app and extensions)

### 4.2 Google Cloud Platform (GCP)

**Cost**: Free for OAuth (no API usage fees for basic sign-in)

Setup steps:
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a new project (e.g., "WagerWall")
3. Navigate to **APIs & Services → OAuth consent screen**
   - Choose "External" user type
   - Fill in app name, support email, developer contact
   - Add scopes: `email`, `profile`, `openid`
   - Add test users during development
   - Eventually submit for Google verification (required before going public)
4. Navigate to **APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID**
   - Create an **iOS** client:
     - Application type: iOS
     - Bundle ID: `com.wagerwall.app`
     - Record the **Client ID**
   - Create a **Web** client (required by Supabase):
     - Application type: Web application
     - Authorized redirect URI: `https://<your-supabase-project>.supabase.co/auth/v1/callback`
     - Record the **Client ID** and **Client Secret**
5. The **Web client** credentials go into Supabase (Dashboard → Auth → Providers → Google)
6. The **iOS client** ID goes into the iOS app's `Info.plist` for the Google Sign-In SDK URL scheme

### 4.3 Supabase

**Cost**: Free tier (500MB DB, 1GB storage, 500K edge function invocations/month). Upgrade to Pro ($25/month) when approaching production.

Setup steps:
1. Create account at [supabase.com](https://supabase.com)
2. Create a new project, record:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Anon (public) key**: Used in the iOS app
   - **Service role key**: Used ONLY in Edge Functions (never in client code)
3. **Configure Auth providers**:
   - Dashboard → Authentication → Providers → Google → Enable
   - Paste the **Web client** OAuth Client ID and Client Secret from GCP
   - Set redirect URL in GCP to match Supabase's callback URL
4. **Configure Auth providers** (Apple Sign-In):
   - Dashboard → Authentication → Providers → Apple → Enable
   - Requires Apple Services ID, Team ID, Key ID, and private key (from Apple Developer portal)
5. **Enable extensions**:
   - Dashboard → Database → Extensions → Enable `pg_cron`, `pg_net` (for HTTP requests from SQL), `uuid-ossp`
6. **Create Storage buckets**:
   - `cbt-content` (public read, admin write) — for CBT lesson media
   - `user-avatars` (authenticated read/write) — for profile pictures
7. **Install Supabase CLI** locally:
   ```bash
   brew install supabase/tap/supabase
   supabase init  # in project root
   supabase link --project-ref <project-id>
   ```
8. **Set up local development**:
   ```bash
   supabase start   # starts local Supabase (Docker required)
   supabase db reset # applies migrations
   ```

### 4.4 APNs Setup for Push Notifications

The push notification flow: **Supabase Edge Function → APNs → User's device**

Setup steps:
1. From Apple Developer portal, you should already have the `.p8` APNs auth key (see 4.1 step 3)
2. Store in Supabase as secrets:
   ```bash
   supabase secrets set APNS_KEY="$(cat AuthKey_XXXXXXXX.p8)"
   supabase secrets set APNS_KEY_ID="XXXXXXXX"
   supabase secrets set APNS_TEAM_ID="XXXXXXXXXX"
   supabase secrets set APNS_BUNDLE_ID="com.wagerwall.app"
   ```
3. Edge Function uses these to sign and send push notifications via APNs HTTP/2 API

---

## 5. Core Features

### 5.1 Onboarding Flow

1. **Welcome screen** — explain what WagerWall does
2. **Google Sign-In / Apple Sign-In** — authenticate via Supabase Auth
3. **Gambling assessment** — brief questionnaire (e.g., adapted PGSI - Problem Gambling Severity Index)
   - Determines severity level and personalizes CBT content
   - Results stored in `user_profiles` table
4. **Screen Time authorization** — request `FamilyControls` authorization
   - `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
   - Must clearly explain why this is needed before prompting
5. **Select apps/categories to block** — use `FamilyActivityPicker` to let user choose
   - Pre-suggest the "Casino" category
   - Allow adding specific apps and websites
6. **Set up accountability partner** (optional but encouraged) — invite via phone number or email
7. **Set blocking schedule** — always-on or scheduled windows
8. **Tutorial** — quick walkthrough of CBT modules and dashboard

### 5.2 CBT Learning Modules

Structured cognitive behavioral therapy content delivered as interactive lessons.

**Module structure**:
- **Lessons** — grouped into modules (e.g., "Understanding Triggers", "Cognitive Distortions", "Building Coping Skills")
- **Content types**: Text, illustrations, audio narration, interactive exercises, quizzes
- **Exercises**: Thought journals, trigger identification worksheets, urge tracking, cognitive restructuring worksheets
- **Progress tracking**: Completion percentage, streak counter, XP/points

**Content delivery**:
- Lesson metadata and text stored in Supabase `cbt_modules` / `cbt_lessons` tables
- Media assets (images, audio) stored in Supabase Storage `cbt-content` bucket
- Lesson content defined as structured JSON (allows rich formatting without a CMS)
- User progress tracked in `user_lesson_progress` table

**Key CBT modules to implement**:
1. Understanding Gambling Addiction — what it is, how it works neurologically
2. Identifying Triggers — emotional, environmental, social triggers
3. Cognitive Distortions in Gambling — gambler's fallacy, illusion of control, chasing losses
4. Urge Surfing — mindfulness techniques to ride out urges without acting
5. Alternative Activities — building healthy replacement behaviors
6. Financial Recovery — budgeting, debt management awareness
7. Relapse Prevention — identifying warning signs, building a prevention plan
8. Building a Support Network — involving others in recovery

### 5.3 App & Website Blocking

**Implementation using Screen Time API**:

```
┌─────────────────────────────────────────────┐
│                  iOS Device                  │
│                                              │
│  ┌──────────────┐    ┌───────────────────┐  │
│  │  WagerWall   │    │  ManagedSettings  │  │
│  │  Main App    │───▶│  Store            │  │
│  │              │    │  (blocks apps &   │  │
│  └──────────────┘    │   websites)       │  │
│         │            └───────────────────┘  │
│         │                     │              │
│  ┌──────────────┐    ┌───────────────────┐  │
│  │  Device      │    │  Shield           │  │
│  │  Activity    │    │  Configuration    │  │
│  │  Monitor     │    │  Extension        │  │
│  │  Extension   │    │  (custom UI when  │  │
│  │  (schedules) │    │   blocked app     │  │
│  └──────────────┘    │   is opened)      │  │
│                      └───────────────────┘  │
│                               │              │
│                      ┌───────────────────┐  │
│                      │  Shield Action    │  │
│                      │  Extension        │  │
│                      │  (handle user     │  │
│                      │   taps on shield) │  │
│                      └───────────────────┘  │
└─────────────────────────────────────────────┘
```

**App targets needed** (each is a separate Xcode target):

1. **Main App** — requests `FamilyControls` authorization, writes to `ManagedSettingsStore` to apply blocks, provides UI for selecting what to block
2. **ShieldConfiguration Extension** — customizes the shield UI shown when a blocked app is opened (WagerWall branding, motivational message, CBT micro-tip)
3. **ShieldAction Extension** — handles button taps on the shield (e.g., "I'm having an urge" → opens WagerWall to urge-surfing exercise)
4. **DeviceActivityMonitor Extension** — runs on a schedule, can dynamically adjust blocks based on time of day or triggers

**What gets blocked**:
- Gambling apps (entire "Casino" category + user-selected individual apps)
- Gambling websites (maintained blocklist applied via `WebContentSettings`)
- Sports betting apps (user-selected)
- Fantasy sports apps (user-selected)

**Blocking modes**:
- **Always On** — 24/7 blocking, can only be disabled with accountability partner approval + cooling-off period
- **Scheduled** — block during high-risk hours (e.g., evenings, weekends)
- **Urge-triggered** — user manually activates blocking during an urge episode

### 5.4 Accountability Partner System

1. **Invitation** — user sends invite via SMS/email (deep link)
2. **Partner app** — partner downloads WagerWall (or receives notifications via SMS/email without the app)
3. **Lock code** — partner sets a code required to disable blocking
4. **Notifications to partner**:
   - User attempted to disable protections
   - User's app heartbeat stopped (possible deletion)
   - User completed a CBT milestone (positive reinforcement)
   - User reported an urge (if user opts in to sharing this)
5. **Cooling-off period** — even with partner code, disabling requires 24-48hr wait

### 5.5 Dashboard

- **Streak counter** — days since last gambling activity (self-reported + inferred from no blocked app attempts)
- **Urge tracker** — log urges with intensity, trigger, and outcome; visualize trends over time
- **CBT progress** — lessons completed, current module, next lesson
- **Money saved** — user inputs previous gambling spend; app calculates estimated savings
- **Mood tracker** — daily check-in, correlates mood with urge patterns
- **Blocked attempts** — count of times a gambling app/site was blocked (via DeviceActivity monitoring)

### 5.6 Emergency / Crisis Features

- **Panic button** — prominent button on dashboard that immediately:
  - Opens a guided urge-surfing exercise (breathing, CBT micro-intervention)
  - Shows motivational content / personal reasons for quitting
  - Optionally texts accountability partner
- **Helpline quick-dial** — one-tap call to:
  - National Problem Gambling Helpline: 1-800-522-4700
  - Crisis Text Line: Text HOME to 741741
- **Crisis resources page** — links to local support groups, therapist finder

---

## 6. Database Schema (Supabase)

### 6.1 Core Tables

```sql
-- Users (extends Supabase auth.users)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    avatar_url TEXT,
    gambling_severity TEXT CHECK (gambling_severity IN ('low', 'moderate', 'high', 'severe')),
    assessment_score INTEGER,
    quit_date TIMESTAMPTZ,
    daily_gambling_spend DECIMAL(10,2),  -- pre-quit average for "money saved" calc
    timezone TEXT DEFAULT 'America/New_York',
    onboarding_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Accountability partners
CREATE TABLE public.accountability_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    partner_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    partner_email TEXT,
    partner_phone TEXT,
    lock_code_hash TEXT,  -- bcrypt hash of the lock code
    status TEXT CHECK (status IN ('invited', 'active', 'removed')) DEFAULT 'invited',
    invited_at TIMESTAMPTZ DEFAULT NOW(),
    activated_at TIMESTAMPTZ
);

-- Device heartbeats (for deletion detection)
CREATE TABLE public.device_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    apns_token TEXT,  -- for push notifications
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
    icon_name TEXT,  -- SF Symbol name
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- CBT lesson definitions
CREATE TABLE public.cbt_lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID REFERENCES public.cbt_modules(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    content JSONB NOT NULL,  -- structured lesson content
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
    exercise_data JSONB,  -- stores user's journal entries, quiz answers, etc.
    UNIQUE(user_id, lesson_id)
);

-- Urge logs
CREATE TABLE public.urge_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    intensity INTEGER CHECK (intensity BETWEEN 1 AND 10),
    trigger_category TEXT,  -- 'emotional', 'environmental', 'social', 'financial', 'boredom'
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
    blocked_category TEXT,  -- e.g., 'casino', 'sports_betting'
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

-- User streaks (materialized by cron job or trigger)
CREATE TABLE public.user_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    current_streak_days INTEGER DEFAULT 0,
    longest_streak_days INTEGER DEFAULT 0,
    last_check_in DATE,
    money_saved_estimate DECIMAL(10,2) DEFAULT 0,
    UNIQUE(user_id)
);
```

### 6.2 Row Level Security (RLS) Policies

```sql
-- All tables: users can only read/write their own data
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.user_profiles
    FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.user_profiles
    FOR UPDATE USING (auth.uid() = id);

-- Accountability partners: user can see their own partnerships
-- Partner can see partnerships where they are the partner
ALTER TABLE public.accountability_partners ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own partnerships" ON public.accountability_partners
    FOR ALL USING (auth.uid() = user_id OR auth.uid() = partner_user_id);

-- CBT content: readable by all authenticated users
ALTER TABLE public.cbt_modules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read modules" ON public.cbt_modules
    FOR SELECT USING (auth.role() = 'authenticated' AND is_published = TRUE);

ALTER TABLE public.cbt_lessons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read lessons" ON public.cbt_lessons
    FOR SELECT USING (auth.role() = 'authenticated' AND is_published = TRUE);

-- Apply similar user-owns-own-data policies to all other tables
-- (urge_logs, mood_logs, blocked_attempts, etc.)
```

### 6.3 Edge Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `check-heartbeats` | pg_cron (every 15 min) | Find devices that missed 3+ heartbeats, notify partner |
| `send-push` | Called by other functions | Send APNs push notification to a user's device(s) |
| `notify-partner` | Called by triggers/functions | Send push/SMS/email to accountability partner |
| `daily-streak-update` | pg_cron (daily at midnight per user TZ) | Update streak counters and money-saved estimates |
| `process-disable-request` | Called when partner approves | Start cooloff timer, schedule protection removal |
| `send-daily-reminder` | pg_cron (configurable per user) | Daily CBT reminder / motivational message push notification |

### 6.4 Database Triggers

```sql
-- Auto-create user_profile and user_streaks on signup
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id) VALUES (NEW.id);
    INSERT INTO public.user_streaks (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

---

## 7. App Architecture

### 7.1 MVVM + Repository Pattern

```
View (SwiftUI)
  │
  ▼
ViewModel (ObservableObject / @Observable)
  │
  ▼
Repository (protocol + implementation)
  │
  ▼
Supabase Swift SDK / Local Storage (SwiftData)
```

### 7.2 Key Services (Singleton/Environment)

| Service | Responsibility |
|---------|---------------|
| `AuthService` | Supabase Auth session management, Google/Apple sign-in |
| `BlockingService` | FamilyControls authorization, ManagedSettingsStore management |
| `HeartbeatService` | Background heartbeat pings to Supabase |
| `NotificationService` | APNs registration, handling incoming notifications |
| `CBTContentService` | Fetch and cache CBT modules/lessons |
| `UrgeTrackingService` | Log urges, manage panic button flow |
| `StreakService` | Track and display streak data |

### 7.3 App Extensions

Each extension is a separate Xcode target with its own `Info.plist` and entitlements:

1. **ShieldConfiguration** (`ShieldConfigurationDataSource`)
   - Provides custom UI for the shield overlay
   - Returns `ShieldConfiguration` with WagerWall branding, motivational text
   - Runs in a very limited sandbox (no network, minimal memory)
   - Communicates with main app via App Group shared container

2. **ShieldAction** (`ShieldActionDelegate`)
   - Handles user taps on shield buttons
   - Options: "Open WagerWall" (launches main app), "I'm struggling" (launches to panic button)

3. **DeviceActivityMonitor** (`DeviceActivityMonitorExtension`)
   - Responds to schedule start/end events
   - Can dynamically adjust `ManagedSettingsStore` based on time

### 7.4 Data Flow for Blocking

```
1. User selects apps to block in FamilyActivityPicker
2. App stores Selection in ManagedSettingsStore:
   - store.shield.applications = selection.applicationTokens
   - store.shield.webDomains = gamblingWebsiteDomains
3. OS immediately enforces blocking (no app running needed)
4. When user opens blocked app:
   a. OS shows shield (ShieldConfiguration provides custom UI)
   b. User taps button → ShieldAction handles it
   c. If "Open WagerWall" → app launches to relevant screen
5. DeviceActivityMonitor can log the attempt and sync to Supabase
```

---

## 8. Implementation Phases

> **Status snapshot (verified 2026-04-28)**: Phases 0–4 are largely complete or partial. The CBT content layer, dashboard, panic button, profile, and accountability-partner UI are all wired to live Supabase repos. The two big remaining items are (a) the actual app/website blocking layer (Phase 1's last bullets — pending Apple entitlement) and (b) Phase 5 launch polish. See CLAUDE.md "Implementation Progress" for the per-feature ground-truth list with file refs.

### Phase 0: Project Hygiene (COMPLETED)

**Goal**: Fix foundational issues so the project builds correctly.

- [x] Fix iOS deployment target from 26.2 to 17.0
- [x] Fix bundle ID from `michaelsong.Wagerwall` to `com.wagerwall.app`
- [x] Externalize credentials from `Config.swift` to `Secrets.xcconfig` (gitignored) with `.xcconfig.example` template
- [x] Create directory structure: `Models/`, `Repositories/`, `ViewModels/`, `Views/{Onboarding,CBT,Blocking,Profile,Components}/`, `Resources/`, `supabase/functions/`
- [x] Create `.gitignore`
- [x] Verified build succeeds

### Phase 1: Foundation (MVP) — IN PROGRESS

**Goal**: Basic app with auth, onboarding, and app blocking

- [x] Xcode project setup (main app target; 3 extension targets deferred until Apple entitlement)
- [x] Supabase project setup with initial migration (`001_initial_schema.sql`)
- [x] Auth flow: Google OAuth via Supabase (**Apple Sign-In still missing** — required by App Store guidelines once any third-party sign-in is offered)
- [~] Onboarding screens — welcome and Screen Time auth step views exist; PGSI assessment lives in Profile but is not in the onboarding flow; quit date / spend / completion summary steps not yet wired into `OnboardingViewModel`
- [ ] App blocking via ManagedSettingsStore (always-on mode) — **not started**, no `FamilyControls`/`ManagedSettings` references in source yet
- [ ] Basic shield UI (ShieldConfiguration extension) — **not started**, no extension target exists
- [x] Simple dashboard with streak counter — extended well beyond Phase 1 scope (mood, urge, panic button)
- [x] Heartbeat service (background pings) — `HeartbeatService` registers a `BGTaskScheduler` task and pings via `HeartbeatRepository`
- [x] Push notification registration — `NotificationService` requests authorization, registers APNs token, persists via `PushTokenRepository`

> **Auth routing caveat**: `AppState.swift:28-30` currently hardcodes `rootScreen = .main` behind a `// TODO: Re-enable auth flow when sign-in is ready` comment. The sign-in/onboarding routing logic exists but is bypassed. Re-enabling it is a prerequisite to closing Phase 1.

### Phase 2: CBT Content — LARGELY COMPLETE

**Goal**: Deliver core therapeutic content

- [x] CBT module/lesson data model and Supabase seeding (`002_cbt_content.sql`)
- [x] Lesson viewer UI (text, images, interactive exercises) — `LessonView`, `LessonCompleteView`
- [x] Journal/worksheet exercises with local + cloud save (lesson type `journal` persists `exercise_data` to `user_lesson_progress`)
- [x] Quiz system with scoring — full subsystem in `Views/CBT/Quiz/` (MCQ, Matching, Swipe cards, session/complete views)
- [x] Progress tracking and module completion flow
- [ ] Daily CBT reminder notifications — push pipeline depends on `send-push` JWT signing landing first
- [~] Seed first 3 modules of content — `002_cbt_content.sql` seeds 3 modules / 9 lessons (Modules 1–3). Modules 4–8 unseeded.

### Phase 3: Accountability & Safety — LARGELY COMPLETE

**Goal**: Social support and deletion resistance

- [x] Accountability partner invitation flow (`InvitePartnerView`, `AccountabilityPartnersView`) — deep-link / SMS handoff still TBD
- [~] Partner notification system (Edge Functions → APNs) — `notify-partner` edge function exists and routes to `send-push`, but `send-push` itself is a stub (no JWT signing, no APNs HTTP/2 call); email path is logging-only (no Twilio/SendGrid)
- [x] Lock code system (partner sets code to disable blocking) — `accountability_partners.lock_code_hash` schema in place; UI for setting/verifying wired
- [x] Cooling-off period for disable requests — `DisableProtectionView` + `DisableRequestStatusView` + `process-disable-request` edge function
- [~] Heartbeat monitoring + partner alerting on app deletion — `check-heartbeats` edge function complete; alert delivery blocked on `send-push`
- [x] Panic button with urge-surfing guided exercise — `PanicButtonView`, `BreathingExerciseView`, `MotivationalCardView`
- [x] Crisis helpline quick-dial integration — `CrisisResourcesView`

### Phase 4: Insights & Engagement — LARGELY COMPLETE

**Goal**: Help users understand patterns and stay engaged

- [x] Urge tracking with detailed logging UI — `LogUrgeView` + `UrgeLogViewModel`
- [x] Mood tracking daily check-ins — `LogMoodView` + `MoodLogViewModel`
- [ ] Data visualization (urge trends, mood correlation, streak history) — `ProgressTabView` exists but charting depth not yet verified
- [x] Money saved calculator — `daily-streak-update` edge function recalculates `money_saved_estimate`; surfaced on dashboard
- [ ] Blocked attempt statistics — depends on Phase 1 blocking layer existing
- [ ] Motivational notifications based on user data patterns — depends on `send-push` JWT
- [ ] Seed remaining CBT modules (4–8)

### Phase 5: Polish & Launch — NOT STARTED

**Goal**: App Store ready

- [ ] Full onboarding polish with animations
- [ ] Accessibility audit (VoiceOver, Dynamic Type) — currently zero `accessibilityLabel`/`accessibilityHint` annotations in source
- [ ] Localization (English first, Spanish as priority #2) — no `.strings`/`.xcstrings` files exist
- [ ] App Store screenshots, description, metadata
- [ ] Privacy policy and terms of service
- [ ] `PrivacyInfo.xcprivacy` manifest (required for iOS 17+)
- [ ] App Store review submission (plan for Family Controls entitlement review)
- [ ] Analytics integration (PostHog or Mixpanel)
- [ ] Crash reporting (Sentry)
- [ ] Subscription paywall (RevenueCat) if going freemium
- [ ] Real test coverage — `WagerwallTests` and `WagerwallUITests` are still default Xcode stubs
- [ ] CI/CD — no `.github/workflows` or `fastlane/` yet

---

## 9. Future Services & Features

### 9.1 Services to Add Later

| Service | Purpose | When |
|---------|---------|------|
| **RevenueCat** | Subscription management (if freemium model) | Phase 5+ |
| **PostHog / Mixpanel** | Product analytics, funnel tracking, feature flags | Phase 5 |
| **Sentry** | Crash reporting, error tracking, performance monitoring | Phase 5 |
| **Twilio / SendGrid** | SMS and email to partners who don't have the app | Phase 3 |
| **OpenAI / Claude API** | AI-powered CBT chatbot for personalized coaching | Post-launch |
| **Stripe** (via RevenueCat) | Payment processing for subscriptions | Phase 5+ |
| **Fastlane + GitHub Actions** | CI/CD: automated builds, TestFlight uploads, App Store deploys | Phase 5 |
| **CloudKit** | Optional iCloud backup/sync of user data | Post-launch |

### 9.2 Future Features

- **AI CBT Coach** — conversational AI (Claude/GPT) that provides personalized CBT responses to user's journal entries and urge reports
- **Group support** — anonymous group chat rooms by recovery stage
- **Therapist integration** — allow a licensed therapist to view (with consent) a client's WagerWall data
- **Financial tools** — integration with budgeting apps, self-exclusion form generators for casinos
- **Apple Watch companion** — urge logging and breathing exercises on wrist
- **Widgets** — home screen widgets showing streak, motivational quote, next CBT lesson
- **Gamification** — badges, achievements, levels (done carefully to avoid triggering gambling-like reward patterns)
- **Self-exclusion assistant** — guided walkthrough for self-excluding from online gambling platforms (each has different processes)
- **Web dashboard** — Supabase-powered web app for accountability partners to monitor without installing the iOS app

---

## 10. App Store & Compliance

### 10.1 App Store Review Considerations

- **Family Controls entitlement**: Apple manually reviews apps requesting this. Prepare a written justification explaining the therapeutic purpose. May take 1-2 weeks.
- **Health claims**: Be careful with language. Say "helps support recovery" not "cures gambling addiction." Consider adding a disclaimer that the app is not a substitute for professional treatment.
- **MDM profile** (if implemented): Apple is very strict about non-enterprise MDM use. May require additional review. Consider making this a separate, clearly-documented feature.
- **Guideline 5.1.1 (Data Collection)**: Must disclose all data collected in App Store privacy labels.

### 10.2 Privacy & Data Protection

- All user data (urges, moods, journal entries) is sensitive health-related information
- While HIPAA may not technically apply (not a covered entity unless partnering with healthcare providers), treat data as if it does
- Implement:
  - End-to-end encryption for journal entries (encrypt client-side before storing in Supabase)
  - Minimal data collection — only collect what's needed
  - Data export feature (user can download all their data)
  - Data deletion feature (user can delete account and all data)
  - Clear privacy policy explaining data handling
- Supabase RLS ensures users can only access their own data
- Never log or store sensitive data in analytics events

### 10.3 Content Considerations

- CBT content should be reviewed by a licensed mental health professional
- Include disclaimers that the app is not a replacement for professional therapy
- Provide prominent links to professional resources (helplines, therapist directories)
- If implementing AI coach, add clear "I am an AI, not a therapist" disclaimers

---

## 11. Open Questions

These should be resolved before or during implementation:

1. **Monetization model**: Free with donations? Freemium (basic free, premium features paid)? Subscription? Free for all to maximize impact?
2. **CBT content authorship**: Who writes the CBT modules? Hire a licensed therapist as content consultant? Use evidence-based public domain resources?
3. **MDM profile**: Include the optional MDM deletion-prevention feature? Adds complexity and App Store review risk.
4. **Apple Sign-In**: Apple requires Apple Sign-In if you offer any other third-party sign-in (Google). This is mandatory per App Store guidelines — already accounted for in this spec.
5. **Offline support**: How much of the app should work offline? CBT lessons should be downloadable. Urge logging should work offline and sync later.
6. **Partner without app**: Should accountability partners need to install WagerWall, or can they function via SMS/email only? SMS/email is lower friction but requires Twilio/SendGrid.
7. **Website blocklist maintenance**: Who maintains the list of gambling websites to block? Could crowdsource or use a public blocklist.
8. **Target audience age**: 17+ on App Store (gambling content). Ensure no users under 17 can sign up.
9. **Beta testing strategy**: TestFlight with a group of users in recovery? Partner with a gambling addiction treatment center?
