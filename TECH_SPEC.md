# iOS Gambling Blocker: Architecture & Technical Feasibility Document

## Current Status

Last verified: 2026-04-28. See `CLAUDE.md` "Implementation Progress" for the full per-feature checklist.

- **App-side feature build**: ~80% of user-facing features are implemented and wired to live Supabase repos — full CBT module/lesson/quiz subsystem, dashboard with streak/mood/urge logging, panic button + breathing exercise, profile/settings, accountability-partner UI with cooling-off disable flow.
- **Backend**: Schema (`001_initial_schema.sql`, 14 tables + RLS + `handle_new_user` trigger) and CBT seed (`002_cbt_content.sql`, 3 of 8 modules) are in place. 4/5 edge functions are production-ready (`check-heartbeats`, `notify-partner`, `process-disable-request`, `daily-streak-update`).
- **Working auth**: Google OAuth via Supabase (`AuthService.swift`). Auth state listener exists.
- **Critical gaps that block this document's blocking architecture**:
  - **Blocking layer not started**: Zero references to `FamilyControls`, `ManagedSettings`, `DeviceActivity`, or `NetworkExtension` in source. None of the extension targets (`ShieldConfiguration`, `ShieldAction`, `DeviceActivityMonitor`, `NEFilterDataProvider`) exist in the Xcode project. Bloom-filter / Radix-tree DNS blocklist not started. Shortcuts Trap onboarding flow not started. Instant Lockdown failsafe not started. **Blocked on Apple Developer enrolment + Family Controls / Network Extension entitlement applications.**
  - **Auth routing bypassed**: `AppState.swift:28-30` hardcodes `rootScreen = .main` behind a `// TODO: Re-enable auth flow when sign-in is ready` — sign-in/onboarding routing is currently disabled.
  - **Apple Sign-In missing**: Required by App Store Guideline 4.8 once Google Sign-In is offered.
  - **Push delivery stubbed**: `send-push` edge function lacks JWT signing and the APNs HTTP/2 call. iOS-side token registration is complete; backend cannot actually deliver notifications yet.
  - **Cron jobs disabled**: `003_cron_jobs.sql` jobs are commented out (`pg_cron` requires Supabase Pro).
- **Polish layer (Phase 5) not started**: default Xcode test stubs, zero accessibility annotations, no localization, no `PrivacyInfo.xcprivacy`, no analytics/Sentry, no CI/CD.
- **Next likely milestones**: (1) re-enable auth routing in `AppState`, (2) add Apple Sign-In, (3) finish `send-push` JWT signing, (4) apply for Apple entitlements so the blocking layer can be started.

---

## 1. Core Blocking Mechanisms

To achieve maximum restriction on a sandboxed iOS device, the app must utilize a layered defense combining Apple's official Screen Time and Network Extension frameworks.

### App-Level (Screen Time API / Family Controls)

- **Function**: Blocks the launch of known gambling apps installed on the device using the `ManagedSettingsStore`.
- **Deletion Prevention**: Utilizes `store.application.denyAppRemoval = true` to lock the blocker app on the home screen so the user cannot simply delete it during a craving.
- **Authorization**: Requires FaceID/TouchID consent to manage the device.

### Network-Level (Local DNS Filter / NEFilterDataProvider)

- **Function**: A lightweight, on-device Network Extension that intercepts all system-wide DNS queries.
- **Execution**: Compares requested domains against a local blocklist. If a match is found (e.g., `betting.com`), it returns an NXDOMAIN error, severing the connection before a Safari or app-based payload can load.

---

## 2. Settings Access & The "Shortcuts Trap"

Because the user can theoretically revoke Screen Time permissions from the native iOS Settings app, we must restrict access to Settings using a combination of psychological friction and native workarounds.

### The Shortcuts Trap (24/7 Baseline)

The user is guided during onboarding to create a native Apple Shortcut automation (**When Settings is Opened → Open Blocker App**). This forcefully kicks the user out of Settings in a fraction of a second.

### The Leniency Window

To ensure the phone remains functional (e.g., connecting to Wi-Fi, pairing Bluetooth), the blocker app features a **"5-Minute Unlock"** button. This temporarily pauses the trap, allowing the user to navigate the Settings app safely.

### The PIN Vault

If the user attempts to disable Screen Time during the Leniency Window, they are blocked by a **randomized 4-digit PIN** generated during onboarding. This PIN is held on your backend servers and is only retrievable via a **48-hour cool-down timer**, breaking the impulse loop.

---

## 3. Vulnerability Mitigation (The Failsafe)

Apple does not allow the Screen Time PIN to protect the VPN menu. A user could theoretically delete the Network Extension profile during the 5-Minute Leniency Window.

### The Instant Lockdown Protocol

The app continuously monitors the VPN status via `NEFilterManager.shared().isEnabled` and the `NEFilterConfigurationDidChange` notification.

**Execution**: If the app detects the VPN was deleted, it immediately triggers the Screen Time API to shield **all** downloaded apps and fully block Safari. The phone remains usable for essential tools (Calls, Texts, Maps, Camera) but is useless for web browsing or entertainment until the user reinstalls the VPN profile inside your app.

---

## 4. App Store Review Likelihood

Apple's App Review process is notoriously strict regarding apps that restrict device functionality. Here is the anticipated compliance breakdown:

| Feature | Likelihood of Approval | Review Strategy / Caveat |
|---------|----------------------|--------------------------|
| Screen Time App Blocking | **High** | Requires applying for the "Family Controls" entitlement from Apple prior to development. |
| Local DNS Network Extension | **High** | Must clearly state in the App Store description and Privacy Policy exactly what network data is evaluated (and that it never leaves the device). |
| Shortcuts Trap | **High** | Apple does not review user-created Shortcuts. Since the user builds it manually, it bypasses App Store code restrictions. |
| Failsafe / Instant Lockdown | **Medium-High** | Must be presented as a clear, opt-in feature (e.g., "Hardcore Mode") during onboarding. If hidden, Apple will reject it under Guideline 2.5 (interfering with normal device operation). |

---

## 5. Database Architecture: Fast & Memory-Efficient DNS Filtering

iOS places a brutal memory limit (typically around **15MB**) on Network Extensions. Loading a raw list of millions of blocked domains will instantly crash the extension.

### Tier 1: Bloom Filter (The Gatekeeper)

A highly compressed, probabilistic bit-array loaded entirely into RAM. It checks if a domain is *likely* on the blocklist in **<2ms** with practically zero memory footprint.

### Tier 2: Radix Tree (The Source of Truth)

If the Bloom Filter flags a domain, the extension queries an on-disk SQLite database formatted as a **Reverse Radix Tree** (e.g., `com → betting → www`). This confirms the block without loading the massive dataset into active memory, preserving battery life and device speed.

---

## 6. Technical Complexities & Roadblocks

- **Entitlement Delays**: Apple can take several weeks to approve a developer's request for the Family Controls API entitlement.
- **User Churn during Onboarding**: The onboarding process is highly complex. The user must authorize Screen Time, set up a randomized PIN, write it down, throw it away, and build a custom Apple Shortcut. High friction here will cause impatient users to drop off before the app is even active.
- **iOS Updates**: Apple frequently updates how Shortcuts and Screen Time behave. A future iOS update could temporarily break the Shortcut trap or introduce a new way to bypass the VPN settings.
