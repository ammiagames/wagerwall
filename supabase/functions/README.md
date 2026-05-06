# Edge Functions

Deno + TypeScript. One folder per function with an `index.ts`. Deploy with `supabase functions deploy <name>`. Invoke at `https://<project>.supabase.co/functions/v1/<name>`.

---

## Files

| Function | Status | Trigger |
|---|---|---|
| `send-push/` | 🟡 STUB | Called by other functions |
| `notify-partner/` | 🟡 push works, email logs only | Called by other functions |
| `check-heartbeats/` | ✅ production | Cron every 15 min (currently disabled — Pro plan) |
| `process-disable-request/` | ✅ production | Cron every 5 min + manual (`{ requestId, action }`) |
| `daily-streak-update/` | ✅ production (with caveat) | Cron midnight UTC |

All functions use `@supabase/supabase-js` with the **service-role key** to bypass RLS (they need to act on behalf of any user).

---

## Required environment

Set as Supabase function secrets (`supabase secrets set FOO=bar`):

| Variable | Used by | Required |
|---|---|---|
| `SUPABASE_URL` | All | ✅ (auto-provided by runtime) |
| `SUPABASE_SERVICE_ROLE_KEY` | All | ✅ (auto-provided) |
| `APNS_KEY` | `send-push` | ⚠️ — `.p8` private key contents; needed for production push |
| `APNS_KEY_ID` | `send-push` | ⚠️ |
| `APNS_TEAM_ID` | `send-push` | ⚠️ |
| `APNS_BUNDLE_ID` | `send-push` | ⚠️ — `com.wagerwall.app` |
| `APNS_ENVIRONMENT` | `send-push` | optional, defaults to sandbox |

When the APNS_* vars aren't set, `send-push` logs and returns a mock response. With them set (and the JWT signing implemented — see below), it should POST to `api.push.apple.com` (production) or `api.sandbox.push.apple.com` (sandbox).

---

## `send-push/` — STUB

**Purpose**: Send APNs push to a user's registered iOS devices.

**Payload**:
```ts
{
    userId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
}
```

**What's wired**: looks up `push_tokens` for the user, iterates them, and (on a 410 response) deletes invalid tokens. Calls APNs with the right URL.

**What's STUBBED**:
- **APNs JWT signing** is not implemented (`index.ts:68–69` comment: *"Full APNs JWT signing requires the private key (.p8 file)"*).
- The `Authorization: bearer <jwt>` header is commented out (`index.ts:101–102`).
- When `APNS_KEY_ID` and `APNS_TEAM_ID` are missing, the function returns a fake success response without calling Apple at all (`index.ts:73–86`).

Net effect: **no real push notifications are delivered** until JWT signing lands. To finish:
1. Read the `.p8` private key from `APNS_KEY`.
2. Sign an ES256 JWT with claims `{ iss: APNS_TEAM_ID, iat: now }` and header `{ alg: "ES256", kid: APNS_KEY_ID }`. Cache for ≤1 hour.
3. POST to `https://api.push.apple.com/3/device/<token>` (HTTP/2). Headers: `apns-topic: APNS_BUNDLE_ID`, `apns-push-type: alert`, `authorization: bearer <jwt>`.
4. Parse response — `200` is success; `410` means delete the token; everything else logs.

**Invoked by**: `notify-partner`, `process-disable-request`, `daily-streak-update`.

---

## `notify-partner/` — push works, email is logging-only

**Purpose**: Notify an accountability partner. Push delivery if the partner has the app; email otherwise.

**Payload**:
```ts
{
    userId: string;
    partnerEmail?: string;
    partnerUserId?: string;
    type: "heartbeat_stale" | "disable_request" | "streak_milestone";
    message: string;
}
```

**What's wired**:
- Looks up the user's display name from `user_profiles` for context.
- If `partnerUserId` is set, invokes `send-push` for that user.
- Maps `type` to a notification title (`"Partner Alert"`, `"Disable Request"`, `"Milestone"`).

**What's STUBBED**:
- Email path (`index.ts:74–82`) is `console.log("Would email partnerEmail: …")` and returns `{ result: "email_logged" }`. No SendGrid/Resend integration.

To finish: add a SendGrid or Resend API key as a function secret, replace the `console.log` with a fetch to their REST API, and handle delivery errors.

**Invoked by**: `check-heartbeats`, `daily-streak-update`.

---

## `check-heartbeats/` — production-ready

**Purpose**: Detect stale device heartbeats and notify the user's accountability partner.

**Logic**:
1. Compute cutoff = `now - 45 min`.
2. Query `device_heartbeats` where `last_heartbeat < cutoff AND is_active = true`.
3. Mark stale rows `is_active = false`.
4. For each affected user, find active partners and call `notify-partner` with `type: "heartbeat_stale"` and `message: "WagerWall may have been uninstalled or disabled on your partner's device."`.

**Invoked by**: cron `*/15 * * * *` (when `pg_cron` is enabled).

No stubs. End-to-end delivery still depends on `notify-partner` → `send-push`, which is gated by the APNs JWT work above.

---

## `process-disable-request/` — production-ready

**Purpose**: Two modes.

### Mode 1: explicit partner action
**Payload**: `{ requestId: string, action: "approve" | "deny" }`

- **approve** → set `disable_requests.status = "approved"`, `partner_approved = true`, `partner_approved_at = NOW()`. Push the user: *"Request Approved — cooling-off period still active."*
- **deny** → set `status = "cancelled"`. Push the user: *"Request Denied — Stay strong!"*

### Mode 2: cleanup
No payload. Sweeps:
- **Approved + past cooloff** → `status = "expired"`. Push: *"Protection Disable Available."*
- **Pending + past cooloff** → `status = "expired"`. No push.

**Invoked by**: cron `*/5 * * * *` (cleanup mode) + manual partner-approval calls.

---

## `daily-streak-update/` — production (with one caveat)

**Purpose**: Daily roll-up — recompute money saved, detect streak milestones, reset on inactivity.

**Logic** (per `user_streaks` row):
1. Compute `today` and `yesterday`.
2. Pull the user's `quit_date` and `daily_gambling_spend` from `user_profiles`.
3. Update `money_saved_estimate` based on days since `quit_date`.
4. If `current_streak_days` is in `[7, 30, 90, 180, 365]`, push a milestone notification to the user and notify all active partners.
5. If `last_check_in < yesterday`, reset `current_streak_days = 0`.

⚠️ **Caveat (`index.ts:45–47`)**: both branches of the streak update assign `current_streak_days = current_streak_days` — i.e., **the cron does not auto-increment**. The streak ticks only when the user manually checks in via the iOS app (which writes `last_check_in = today` and bumps the day count client-side, then the streak repo updates).

This is a defensible design ("a streak only counts if you show up") but it's not what the comment suggests. If you want auto-increment, replace lines 45–47 with `lastCheckIn === yesterday ? current + 1 : current`.

**Invoked by**: cron `0 0 * * *` (midnight UTC).

---

## Adding a new function

1. Create `supabase/functions/<name>/index.ts`.
2. Standard Deno entrypoint:
   ```ts
   import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
   import { createClient } from "@supabase/supabase-js";

   const supabase = createClient(
       Deno.env.get("SUPABASE_URL")!,
       Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
   );

   serve(async (req) => {
       // ...
       return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" }});
   });
   ```
3. Test locally: `supabase functions serve <name>` then `curl http://localhost:54321/functions/v1/<name> -d '...'`.
4. Deploy: `supabase functions deploy <name>`.
5. If you need new secrets: `supabase secrets set FOO=bar`.
6. To invoke from another function: `supabase.functions.invoke("name", { body: {…} })`.

---

## Conventions

- **Functions are infallible from the client's perspective**: catch every error per-row and continue. A single bad row should not blow up an entire cron run. Existing functions follow this — keep doing it.
- **Service role key is for functions only**. Never embed it in the iOS app or expose it client-side.
- **Idempotency matters for cron**. `process-disable-request` cleanup runs every 5 minutes and only finds rows that haven't already transitioned. `check-heartbeats` flips `is_active = false` once. If you add a new cron function, design for repeated runs.
