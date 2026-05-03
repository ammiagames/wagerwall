# WagerWall Blocking Architecture — First-Principles Design

> **Purpose**: This is the implementation-grade design for WagerWall's core blocking system. Where `TECH_SPEC.md` sketches the strategy, this document derives it from the underlying iOS primitives, makes the math explicit, enumerates every known bypass, and proposes the engineering plan to actually build it.
>
> **Status**: design-only. None of this is implemented yet (verified 2026-04-28). Phase 12 in CLAUDE.md tracks build progress.

---

## 0. Executive Summary

WagerWall blocks gambling using two complementary layers, neither of which is sufficient on its own:

| Layer | Mechanism | Blocks | Cost | Survives app delete? |
|---|---|---|---|---|
| **1. App-level** | Screen Time API (`FamilyControls` + `ManagedSettings`) | Gambling apps installed on device | Zero CPU/battery — OS enforces at launch | **No** — auth revoked on delete |
| **2a. Network DNS proxy** | On-device `NEDNSProxyProvider` + bloom filter | Plain DNS queries from *every* browser | <2ms DNS latency, <1.8MB resident, sub-1% battery | **Yes** if installed via password-protected `.mobileconfig` profile |
| **2b. Packet tunnel (mandatory)** | `NEPacketTunnelProvider` capturing port 53/443/853 selectively | Encrypted DNS (DoH/DoT) and per-network DNS bypass via DDR | ~3–5ms TCP setup, ~3MB resident, ~1–2% battery | Same as 2a |

Together they cover the four ways a determined user accesses gambling on an iPhone:
1. Tap a gambling app → Layer 1 shields it.
2. Open Safari and type `betway.com` → Layer 2 returns NXDOMAIN; Layer 1 also blocks via `WebContentSettings`.
3. Open Chrome/Brave/Firefox and type `betway.com` → Layer 1 doesn't see this (Apple only gives Safari to `WebContentSettings`); Layer 2 catches it at DNS.
4. Use a hardcoded-IP URL or a VPN-tunneled gambling app → see §5 attack surface; this is the residual risk we mitigate with failsafes.

Then a **failsafe layer** (§6) detects bypass attempts and either applies an Instant Lockdown (every non-essential app shielded) or alerts the accountability partner. That layer is what makes the whole thing impulse-resistant rather than just technically functional.

The goal is **harm reduction during the impulse window**, not perfect prevention. A user with hours of patience and technical skill can defeat any iOS-resident system. What matters is making the gap between "I want to gamble" and "I can gamble" wide enough that the urge passes — research on impulse control suggests anywhere from 5–60 minutes is usually enough.

---

## 1. The iOS Threat Model & What's Actually Possible

Before designing, let's be honest about constraints:

**What iOS lets a third-party app do**
- Read `FamilyControls` authorization status; request it from the user.
- Receive opaque `ApplicationToken`s and `WebDomainToken`s from `FamilyActivityPicker` — these are *privacy-preserving handles*, not bundle IDs. The app never learns which apps the user picked.
- Hand those tokens to `ManagedSettingsStore` and ask the OS to shield them.
- Run a `NEDNSProxyProvider` extension that intercepts DNS queries.
- Run shield extensions in separate sandboxed processes.
- Detect (but not prevent) a user disabling the proxy or revoking Screen Time auth.

**What iOS does NOT let a third-party app do**
- Prevent its own deletion (no API; `denyAppRemoval` is a system-wide hammer that affects all apps and can itself be disabled by revoking Screen Time auth).
- Lock the Settings app or the VPN/DNS menu.
- Read the bundle IDs that an `ApplicationToken` corresponds to.
- See DNS queries from apps that use DoH to hardcoded resolvers (Firefox, Brave with DoH on).
- Enforce filtering when iCloud Private Relay is active for Safari traffic.
- Programmatically install an `.mobileconfig` profile — only Safari/Mail can install profiles, and only with explicit user consent.
- Install a Network Extension into a Configuration Profile that survives app deletion *unless* the user manually accepts the profile install and (optionally) the profile is signed.

These constraints define the design. Everything below is engineering around them.

---

## 2. Layer 1 — App Blocking via Screen Time API

### 2.1 The frameworks

Apple's Screen Time API is not one framework but four cooperating ones, introduced in iOS 15 and stabilized in iOS 16:

| Framework | Role |
|---|---|
| `FamilyControls` | Authorization. Gates access to all the others. |
| `ManagedSettings` | The *apply* mechanism — a key-value store of restrictions the OS enforces. |
| `DeviceActivity` | Scheduling and event monitoring (run code at 9pm, react when user opens an app for 30min). |
| `ManagedSettingsUI` | Shield UI extension points. |

`FamilyActivityPicker` is a SwiftUI view that returns a `FamilyActivitySelection` of opaque tokens.

### 2.2 Authorization

```swift
import FamilyControls

let center = AuthorizationCenter.shared

// In app: request once during onboarding
try await center.requestAuthorization(for: .individual)

// Status thereafter:
center.authorizationStatus  // .notDetermined | .denied | .approved
```

`.individual` is for self-managed devices (an adult managing their own phone — our case). `.child` requires Family Sharing and a parent device, which doesn't apply here.

**Critical lifecycle facts:**
- Authorization persists across app launches, reboots, and OS updates.
- Authorization is **revoked when the app is deleted**. This is the central reason Layer 1 alone is insufficient — uninstalling WagerWall wipes every Screen Time setting we configured.
- Authorization can be revoked manually by the user in Settings → Screen Time → "Remove WagerWall from Screen Time."

### 2.3 The opaque token model

When the user picks apps to block via `FamilyActivityPicker`:

```swift
import FamilyControls

@State private var selection = FamilyActivitySelection()

FamilyActivityPicker(selection: $selection)
// selection.applicationTokens : Set<ApplicationToken>
// selection.categoryTokens    : Set<ActivityCategoryToken>
// selection.webDomainTokens   : Set<WebDomainToken>
```

`ApplicationToken` is an opaque `Data`-backed handle. **You cannot read the underlying bundle ID.** Apple does this so a recovery app cannot snoop on what apps a user has installed. You can:
- Round-trip the token through `ManagedSettings`.
- Persist it (via `Codable`) for later re-application.
- Display the app's icon and name in your own UI by passing the token to `Label(_ token: ApplicationToken)`.

The same applies to `WebDomainToken` (you don't see the domain string) and `ActivityCategoryToken` (you don't see the category name).

**Implication for blocklist curation**: we cannot ship a "default Casino apps" list inside the app — there's no way to construct an `ApplicationToken` from a bundle ID. We can only:
- Pre-suggest the *Casino* category token (which the user selects from the picker), or
- Have the user manually pick apps via `FamilyActivityPicker`.

### 2.4 ManagedSettingsStore — the apply mechanism

```swift
import ManagedSettings

let store = ManagedSettingsStore(named: .gambling)  // composable named stores

// Block specific apps (from FamilyActivityPicker)
store.shield.applications = selection.applicationTokens

// Block all apps in chosen categories (e.g., Casino)
store.shield.applicationCategories = .specific(selection.categoryTokens)

// Block specific web domains (Safari only)
store.shield.webDomains = selection.webDomainTokens
store.shield.webDomainCategories = .specific(selection.categoryTokens)

// Lockdown levers
store.application.denyAppRemoval = true             // system-wide app delete lock
store.application.denyAppInstallation = true        // no new installs
store.dateAndTime.requireAutomaticDateAndTime = true // defeat clock-rollback bypass
```

**How the OS actually enforces this** (mechanical model from observed behavior):
1. App writes to `store.shield.applications`.
2. The setting is persisted to a system database (the *SystemPolicy* configuration store).
3. SpringBoard, on every app launch, consults SystemPolicy.
4. If the launched app's identity is in any active store's shield set, SpringBoard intercepts: instead of proceeding with launch, it presents the shield UI (rendered using the data your `ShieldConfigurationExtension` provides — see §2.6).
5. The blocked app's process **never starts**. Zero CPU, zero battery, zero memory used by the block itself.

Multiple named stores (`ManagedSettingsStore(named: .gambling)`, `ManagedSettingsStore(named: .scheduledNight)`) can coexist; the union of their shields is enforced. This is how you compose "always-on casino apps" + "9pm–6am also block social media."

**Persistence**: settings live in SystemPolicy independent of your app process. Killing the app, rebooting, or even disabling the WagerWall app's background refresh does NOT lift the block. Only app deletion or Screen Time auth revocation wipes them.

### 2.5 Web blocking via Screen Time — the Safari-only gotcha

`store.shield.webDomains` and `store.application.webContent.blockedByFilter` route through Apple's `WebContentSettings`, which is implemented inside **WebKit on Safari**. Chrome, Brave, Firefox, DuckDuckGo, and any non-WebKit browser **bypass it entirely** (well, technically all iOS browsers use WebKit, but they may have their own URL routing). In practice, treat Layer 1 web blocking as Safari-only and rely on Layer 2 (DNS) for cross-browser coverage.

### 2.6 The three shield extensions

Each is a separate Xcode target with its own bundle ID, Info.plist, and entitlements. They run in **isolated sandbox processes** with tight memory budgets and no network access. They communicate with the main app exclusively via an **App Group shared container**.

#### 2.6.1 `ShieldConfigurationExtension` — the look of the block

```swift
import ManagedSettings
import ManagedSettingsUI

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: Theme.deepPurple,
            icon: UIImage(named: "WagerWallIcon"),
            title: ShieldConfiguration.Label(text: "Pause for a moment", color: .white),
            subtitle: ShieldConfiguration.Label(text: motivationalSubtitle(), color: .white.withAlphaComponent(0.8)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Open WagerWall", color: .white),
            primaryButtonBackgroundColor: Theme.accent,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "I'm struggling", color: .white)
        )
    }
}
```

**Constraints** observed in practice:
- Memory budget commonly cited as ~50MB; in practice ~30MB is the safe ceiling.
- **No network access** — cannot fetch fresh motivational copy on demand.
- **Synchronous** — runs in milliseconds; long work crashes the extension and the OS shows a generic shield instead.
- Reads everything from the App Group shared container (set by main app when copy needs updating).

#### 2.6.2 `ShieldActionExtension` — what happens on tap

```swift
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Log attempt + deep link to main app
            SharedContainer.appendBlockedAttempt(token: application)
            SharedContainer.setNextLaunchRoute(.dashboard)
            completionHandler(.defer)  // close shield, let user navigate
        case .secondaryButtonPressed:
            SharedContainer.appendBlockedAttempt(token: application)
            SharedContainer.setNextLaunchRoute(.panicButton)
            completionHandler(.defer)
        @unknown default:
            completionHandler(.none)
        }
    }
}
```

`.defer` dismisses the shield and lets the user navigate (typically to WagerWall via the deep link the main app picks up on next launch). `.close` keeps the shield up. `.none` returns control to the OS without a specific response.

#### 2.6.3 `DeviceActivityMonitorExtension` — schedule-driven adjustments

Used for time-window blocking ("9pm–6am block sports betting") and event detection ("if user attempted to open a gambling app 3+ times in 1 hour, escalate intervention").

```swift
import DeviceActivity
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore(named: .scheduledNight)

    override func intervalDidStart(for activity: DeviceActivityName) {
        // Apply additional restrictions during high-risk window
        store.shield.applicationCategories = .specific(SharedContainer.eveningBlockTokens)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        store.clearAllSettings()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                          activity: DeviceActivityName) {
        // User hit a threshold (e.g., 3 blocked-app attempts in 1hr) — escalate
        SharedContainer.flagEscalation(reason: .repeatedAttempts)
    }
}
```

Schedules are registered from the main app:

```swift
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 21, minute: 0),
    intervalEnd: DateComponents(hour: 6, minute: 0),
    repeats: true
)
let event = DeviceActivityEvent(
    applications: SharedContainer.gamblingTokens,
    threshold: DateComponents(minute: 1)  // any open of these apps for 1+min fires event
)
try DeviceActivityCenter().startMonitoring(
    .nightly,
    during: schedule,
    events: [.repeatedAttempts: event]
)
```

### 2.7 The deletion vulnerability

`FamilyControls` authorization is held in a per-app database that's destroyed when the app is uninstalled. When auth is revoked:
1. All `ManagedSettingsStore` settings owned by that app are wiped.
2. All `DeviceActivity` schedules are cancelled.
3. The shield extensions stop being invoked.
4. The user can immediately access every previously-blocked app.

`store.application.denyAppRemoval = true` is the only knob iOS gives us, and it has two limitations:
- It blocks deletion of *all* apps system-wide while active, not just WagerWall — a heavy-handed UX.
- The user can disable it by going to Settings → Screen Time → Remove WagerWall from Screen Time, which revokes auth and clears the setting.

So `denyAppRemoval` is an *impulse barrier*, not a hard lock. Combined with the Shortcuts Trap (§6.2) and a randomized PIN required to access Settings (§6.3), it can extend the bypass loop from "30 seconds" to "tens of minutes," which is enough to defuse most urges.

This is precisely why Layer 2 has to be deletion-resistant on its own.

---

## 3. Layer 2 — Website Blocking via NEDNSProxyProvider

### 3.1 Why DNS-level (and not packet tunneling)

iOS Network Extensions support five provider types:

| Provider | Captures | Memory budget | Battery cost | Latency added |
|---|---|---|---|---|
| `NEPacketTunnelProvider` | All IP packets | 50MB | High (every packet through extension) | 5–30ms |
| `NEAppProxyProvider` | TCP/UDP flows from configured apps | 15MB | Medium | 2–10ms |
| `NETransparentProxyProvider` | TCP/UDP flows by rule | 15MB | Medium | 2–10ms |
| `NEFilterDataProvider` | Flows for inspection (allow/drop) | 6MB | Low–Medium | 1–5ms |
| **`NEDNSProxyProvider`** | DNS queries only | **15MB** | **Very low** (idle between queries) | **<2ms** |

For a domain blocklist, DNS is the perfect attack surface: every browser, every app, every URL bar entry passes through DNS resolution before the connection opens. Catching `betway.com` at DNS means we don't have to inspect a single TLS handshake or HTTP byte. The cost is essentially the cost of an extra hash lookup per query, which is unmeasurable against the natural variance of network round-trips.

A packet tunnel works too, but it routes every byte of every connection through our extension — high battery cost, latency on every connection, and complex failure modes when the extension crashes mid-stream. DNS proxy is the surgical strike.

### 3.2 NEDNSProxyProvider mechanics

```swift
import NetworkExtension

class DNSFilterProvider: NEDNSProxyProvider {
    private var bloom: BloomFilter!         // mmap'd from App Group
    private var radixDB: RadixTreeDB!       // SQLite-backed reverse trie

    override func startProxy(options: [String : Any]?,
                              completionHandler: @escaping (Error?) -> Void) {
        do {
            self.bloom = try BloomFilter.mmap(at: SharedContainer.bloomFilterURL)
            self.radixDB = try RadixTreeDB.open(at: SharedContainer.radixDBURL)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let udp = flow as? NEAppProxyUDPFlow else { return false }
        Task { await handleDNSFlow(udp) }
        return true
    }

    private func handleDNSFlow(_ flow: NEAppProxyUDPFlow) async {
        flow.open(withLocalEndpoint: nil) { [weak self] err in
            guard err == nil else { return }
            self?.pumpQueries(flow)
        }
    }

    private func pumpQueries(_ flow: NEAppProxyUDPFlow) {
        flow.readDatagrams { [weak self] datagrams, endpoints, err in
            guard let self, let datagrams, let endpoints, err == nil else {
                flow.closeReadWithError(err)
                return
            }
            for (data, endpoint) in zip(datagrams, endpoints) {
                self.processQuery(data: data, from: endpoint, flow: flow)
            }
            self.pumpQueries(flow)  // continue pumping
        }
    }

    private func processQuery(data: Data, from endpoint: NWEndpoint, flow: NEAppProxyUDPFlow) {
        guard let qname = DNSWire.parseQuestionName(data) else {
            forwardUpstream(data: data, endpoint: endpoint, flow: flow); return
        }
        if shouldBlock(qname) {
            let nx = DNSWire.synthesizeNXDOMAIN(for: data)
            flow.writeDatagrams([nx], sentBy: [endpoint]) { _ in }
            return
        }
        forwardUpstream(data: data, endpoint: endpoint, flow: flow)
    }

    private func shouldBlock(_ qname: String) -> Bool {
        guard bloom.mightContain(qname) else { return false }   // 99.9% of queries return here in <1ms
        return radixDB.contains(reversed: qname)                 // 0.1% confirm against disk
    }
}
```

### 3.3 The DNS query lifecycle through the extension

For a non-blocked query (the 99%+ case):

```
App → mDNSResponder → [our NEDNSProxy] → bloom.mightContain("ads.example.com") → false
                                        → forward to 1.1.1.1
                                        → response back through proxy
                                        → mDNSResponder → App
```

Added latency: parse question name (~50µs) + bloom check (~10µs) + flow plumbing (~500µs–1.5ms). On a fast network this is undetectable; on a slow network it's noise.

For a blocked query (rare, by definition):

```
App → mDNSResponder → [our NEDNSProxy] → bloom.mightContain("betway.com") → true
                                        → radixDB.contains("com.betway") → true
                                        → synthesize NXDOMAIN response
                                        → write to flow
                                        → mDNSResponder → App (NXDOMAIN)
```

The blocked query is actually *faster* than a network round-trip: we synthesize the response in <1ms vs ~30ms for a real lookup. The browser sees a normal "site not found" error — no network indication that filtering is happening.

mDNSResponder caches aggressively (TTLs respected, plus a negative cache), so most queries don't even reach our extension. Typical iPhone seeing maybe 50–200 unique DNS queries per hour during active use — a budget our extension handles with milliseconds of total CPU.

### 3.4 The 15MB memory budget

This is the hard constraint that drives the bloom-filter design. iOS kills the extension immediately if it exceeds the budget, which means:
- The user's web traffic suddenly works again (no proxy = no filter = unrestricted DNS).
- No crash log or notification — just silent unprotection.

Allocations to budget for:
- Swift runtime + framework code: ~3MB
- Bloom filter (1M items @ 0.1% FP): ~1.2MB
- DNS parsing buffers + per-flow state: ~500KB
- mmap'd radix tree pages (LRU): ~2MB
- Slack: ~5MB
- **Total target**: ~12MB resident. Leave 3MB margin.

The naive approach — load the blocklist as `Set<String>` — costs ~20–50 bytes per domain (Swift's `String` is a fat pointer with inline storage and overhead) × 500k–1M domains = 10–50MB. **Instant kill.**

### 3.5 What survives app deletion (and what doesn't)

Two installation modes for the DNS filter:

**Mode A: App-managed (`NEDNSProxyManager`)**
```swift
let manager = NEDNSProxyManager.shared()
let proto = NEDNSProxyProviderProtocol()
proto.providerBundleIdentifier = "com.wagerwall.app.DNSFilter"
manager.providerProtocol = proto
manager.localizedDescription = "WagerWall DNS Filter"
manager.isEnabled = true
try await manager.saveToPreferences()
```
- Easy to install during onboarding (one permission prompt).
- Easy to update (live config changes via App Group).
- **Wiped when WagerWall is deleted.** Auth tied to app identity.

**Mode B: Configuration-profile-installed (`.mobileconfig`)**
- App generates a `.mobileconfig` XML payload containing a `com.apple.networkextension` payload referencing our extension bundle, plus a `RemovalPassword`.
- App opens the file in Safari (or shares via Mail).
- User manually accepts the install in Settings → General → VPN & Device Management.
- Profile + extension persist **independent of the app** — uninstalling WagerWall does *not* remove the profile, so DNS filtering keeps working.
- To remove the profile, user must enter the `RemovalPassword`, which we either: (a) hold server-side and only release after 48hr cooldown, or (b) hand to the accountability partner.

Mode B is what Gamban and BetBlocker use to be deletion-resistant. **Validation needed (see §10):** confirm Apple still permits non-MDM apps to distribute Network-Extension-bearing mobileconfigs in 2025–2026; this has been quietly tightened in past iOS versions.

The recommended deployment is **both modes simultaneously**:
- Default install: Mode A (low friction, blocks immediately).
- "Hardcore Mode" upgrade in onboarding: Mode B with partner-held removal password.

---

## 4. The Bloom Filter

### 4.1 Why probabilistic membership at all

A perfect (zero-false-positive) blocklist of N domains needs at minimum log₂(N) bits per item just to address the set, and in practice ~80–200 bits per item for a hash table. For our scale (500k–1M domains), that's 5–25MB, blowing the 15MB budget by itself.

A bloom filter accepts a small false-positive rate (say 0.1%) in exchange for a constant ~10 bits per item. We get our blocklist into ~1MB and have headroom for everything else.

The "false positive" failure mode here is **good**: when bloom incorrectly says "blocked," we fall through to the on-disk radix tree, which has the ground truth. The only cost is a few hundred microseconds of disk I/O on 1 in 1000 lookups — negligible.

False *negatives* (a blocked domain incorrectly passing) are mathematically impossible with bloom — if the domain was inserted, all its bits are set, and the query will hit them all. This is the property we need.

### 4.2 Sizing math

For a bloom filter with `n` items and target false-positive rate `p`:
- Optimal bit array size: **m = -n · ln(p) / (ln 2)²**
- Optimal hash count: **k = (m/n) · ln 2**

| n (items) | p (FP rate) | m (bits) | m (bytes) | k (hashes) |
|---|---|---|---|---|
| 100k | 0.001 (0.1%) | ~1.44M | 180 KB | 10 |
| 500k | 0.001 | ~7.2M | 900 KB | 10 |
| 1M | 0.001 | ~14.4M | 1.8 MB | 10 |
| 1M | 0.0001 (0.01%) | ~19.2M | 2.4 MB | 13 |

We'll target **n=1M, p=0.001**, giving a **1.8MB** bloom filter and **10 hash functions**. This comfortably covers every gambling-related domain we'd want to ship.

### 4.3 The double-hashing trick

Computing 10 independent hashes per query would dominate our CPU budget. The standard trick:

> Given two independent hash values h₁ and h₂, the i-th bloom hash can be computed as: **gᵢ(x) = (h₁(x) + i · h₂(x)) mod m**

So we only ever compute *one* 128-bit hash per query (using e.g. MurmurHash3-128 or xxHash3-128), split it into h₁ (low 64 bits) and h₂ (high 64 bits), then derive all k bit positions arithmetically. Total per-query cost: one hash + 10 multiply-adds + 10 bit reads. Sub-microsecond on modern silicon.

```swift
struct BloomFilter {
    let bits: UnsafeBufferPointer<UInt8>   // mmap'd
    let m: UInt64
    let k: Int

    func mightContain(_ domain: String) -> Bool {
        let normalized = domain.lowercased().asciiTrimmed
        let (h1, h2) = MurmurHash3.x64_128(normalized)
        for i in 0..<k {
            let bit = (h1 &+ UInt64(i) &* h2) % m
            let byte = bits[Int(bit / 8)]
            if (byte & (1 << (bit % 8))) == 0 { return false }
        }
        return true
    }
}
```

### 4.4 Two-tier: bloom + on-disk radix tree

Bloom filter answers *"is this domain possibly blocked?"* in <10µs with no I/O.

When bloom says yes, we need to confirm against the actual list. The on-disk store should be:
- Compact (we may have 1M entries)
- Lookup-friendly without loading everything into RAM
- Naturally support wildcard subdomain blocking (`*.betway.com` blocks `sports.betway.com`, `mobile.betway.com`, etc.)

A **reverse radix tree** (also called a reverse PATRICIA trie) fits this perfectly. Domains are stored right-to-left because the hierarchy is on the right (`.com` is the root, `.betway` is a child, `www` is a leaf). Wildcard subdomain blocking becomes a tree-walk truncation: if we block `com.betway.*`, then any query that traverses past `com → betway` is a hit regardless of what comes next.

Storage options:
- **SQLite with a clever schema** (rows: `(reverse_domain TEXT PRIMARY KEY, is_wildcard BOOL)`, indexed) — simple, mature, works.
- **Custom packed binary trie** (e.g., LOUDS-encoded) — smaller and faster but custom code to maintain.

For a v1, SQLite is the right call: ~10MB on disk for 1M domains, sub-millisecond lookup with proper indexing, zero custom code.

```sql
CREATE TABLE blocked_domains (
    reverse_domain TEXT PRIMARY KEY,  -- "com.betway", "uk.co.bet365"
    is_wildcard BOOLEAN NOT NULL DEFAULT 1
);
-- Lookup: did 'sports.betway.com' (reversed: 'com.betway.sports') match anything?
-- SELECT 1 FROM blocked_domains
-- WHERE reverse_domain = 'com.betway.sports'
--    OR (is_wildcard AND 'com.betway.sports' GLOB reverse_domain || '.*')
-- LIMIT 1;
```

Better in practice: precompute all parent domains at lookup time and check exact membership only:

```swift
func contains(reversed qname: String) -> Bool {
    // qname = "com.betway.sports"
    // generate ["com.betway.sports", "com.betway", "com"] and check if any is a wildcard hit
    let parts = qname.split(separator: ".")
    for cut in (1...parts.count).reversed() {
        let candidate = parts[0..<cut].joined(separator: ".")
        if exactMatch(candidate) { return true }
    }
    return false
}
```

This is O(depth) lookups, depth typically 3–4, all hitting the SQLite primary key index → <1ms total even on a cold cache.

### 4.5 Update pipeline

The blocklist is a moving target. New gambling sites appear; some operators rotate domains. We rebuild server-side and ship the result as a binary blob.

**Server-side build (nightly cron)**
```
1. Pull source lists:
   - StevenBlack hosts (gambling category)
   - Curated WagerWall list (manually moderated)
   - User reports (after moderation)
2. Normalize: lowercase, strip wildcards, dedupe.
3. Compute bloom filter binary blob.
4. Build SQLite radix DB.
5. Sign + upload to Supabase Storage.
6. Bump version manifest.
```

**Client fetch (background task, weekly)**
```
1. Background-fetch the manifest (small JSON: {version, urls, sha256s}).
2. If newer than installed, download bloom + radix files.
3. Verify sha256.
4. Atomic-swap into App Group container (delete old after new is verified).
5. Notify NE provider via NEDNSProxyManager save → triggers reload.
```

### 4.6 Binary blob format for the bloom filter

```
struct WWBloom {
    magic:     [4]byte  = "WWBL"
    version:   uint32   = 1
    m:         uint64   // bit array length
    k:         uint8    // hash count
    n_est:     uint64   // estimated insert count (for FP estimation)
    timestamp: uint64   // epoch seconds when generated
    sha256:    [32]byte // checksum of bits[]
    bits:      [m/8]byte
}
```

Memory-mapped from the App Group container into the extension's address space, no decode step needed. Cost: one `mmap` syscall and a sha256 verification at load time.

---

## 5. The Bypass Attack Surface

This is the most important section in the document. Every entry below is a way a determined user can defeat the technical layers. The failsafe layer (§6) is designed to detect and respond to most of them.

### 5.1 User toggles the DNS proxy off in Settings

iOS gives no API to prevent this. User opens Settings → General → VPN, DNS & Device Management → DNS → toggles WagerWall off → website blocking is dead.

**Detection**: subscribe to `NEDNSProxyConfigurationDidChange` notifications and poll `NEDNSProxyManager.shared().isEnabled`.

**Response**: Instant Lockdown (§6.1) — shield every non-essential app via Layer 1, brick the phone for entertainment until DNS proxy re-enabled.

### 5.2 User revokes Screen Time authorization

Same surface, different toggle. Settings → Screen Time → Remove WagerWall.

**Detection**: poll `AuthorizationCenter.shared.authorizationStatus`; the value drops to `.denied`.

**Response**: notify accountability partner immediately; if running, app shows a full-screen "Protections removed" alert; partner is told via push + email.

### 5.3 User deletes the WagerWall app

**Detection**: heartbeat. Main app pings Supabase every ~4hr (BGTaskScheduler). Server cron runs every 15min, flags devices with no heartbeat in 24hr as "presumed deleted." Partner is notified.

**Mitigation if Mode B (.mobileconfig) is installed**: DNS filter survives. Layer 1 (app blocking) is gone, but website blocking stays active — the partial protection that matters most for online gambling.

### 5.4 User changes per-network DNS to public resolver — CONFIRMED BYPASS via DDR

User opens WiFi settings → Configure DNS → Manual → adds 1.1.1.1 (or 8.8.8.8, 9.9.9.9). **This bypass is real and trivially easy.**

The mechanism is subtler than just "per-network DNS overrides our proxy":
- Plain UDP/53 queries to a manually-configured resolver IP **are still seen by NEDNSProxyProvider**.
- BUT iOS auto-discovers whether the configured resolver advertises an encrypted DNS endpoint via **Discovery of Designated Resolvers (DDR)** — and 1.1.1.1, 8.8.8.8, 9.9.9.9 all do.
- When DDR succeeds, iOS **silently upgrades to DoH/DoT and bypasses NEDNSProxyProvider entirely**. `handleNewFlow()` is never called. `systemDNSSettings` returns nil to the extension.
- The user doesn't need to know any of this — they just type "1.1.1.1" and iOS does the upgrade automatically.

Source: [Quinn "The Eskimo!" — Apple DevForums #729619](https://developer.apple.com/forums/thread/729619): *"The system does not route secure DNS transactions to a DNS proxy server."* Behavior unchanged through iOS 26.

The same applies to a DoH/DoT profile installed via Settings → General → VPN, DNS & Device Management — those go around the DNS proxy by design.

**Implication**: Phase 12.9 (`NEPacketTunnelProvider` capturing port 53/443/853) is **not optional** for a serious blocker. It must be wired in for any user serious about blocking, because the DDR bypass is one tap away. The packet tunnel can capture port 53/853 directly and inspect SNI on port 443 to drop connections to the well-known DoH endpoint set (cloudflare-dns.com, dns.google, dns.quad9.net, mozilla.cloudflare-dns.com, etc.).

The trade-off is real: a packet tunnel runs in user-space and every byte routes through it. Mitigation is to use `includedRoutes` to only capture port 53/853 traffic and use `NEFilterDataProvider` for port 443 SNI inspection — keeping the bulk of traffic on the fast path.

### 5.5 User uses DNS-over-HTTPS (DoH) directly — CONFIRMED, no Apple-blessed mitigation

Modern Firefox, Brave, and Chromium-based browsers can use DoH to a hardcoded resolver (cloudflare-dns.com, dns.google, etc.). DoH requests look like normal HTTPS to port 443, so our DNS proxy never sees them.

**Apple has explicitly stated there is no Apple-blessed way to force in-app DoH through `NEDNSProxyProvider`.** The only mitigation paths:
- `NEPacketTunnelProvider` (per §5.4) catches all traffic including DoH endpoints; we drop by IP/SNI.
- `NEFilterDataProvider` inspects TLS ClientHello SNI on port 443; drop connections to known DoH endpoint hosts.

Maintain the DoH endpoint blocklist server-side (it's a known, finite set of ~30 endpoints) and ship it alongside the bloom filter update.

**Forward-looking note**: WWDC25 Session 234 introduced a new **`url-filter-provider`** Network Extension type in iOS/macOS 26 that filters full URLs system-wide. It currently appears to be MDM-only. If Apple opens this to consumer apps, it would dramatically simplify DoH coverage — worth tracking for a v2.

### 5.6 iCloud Private Relay

When enabled, Private Relay routes Safari traffic (and some iCloud-related traffic) through Apple + Cloudflare proxies using **Oblivious DoH (ODoH)** — encrypted DNS that, by the §5.5 logic, bypasses NEDNSProxyProvider.

Apple's CoreOS DTS (Matt Eaton, [DevForums #689889](https://developer.apple.com/forums/thread/689889)) explicitly states that `NEFilterDataProvider` and `NEPacketTunnelProvider` take precedence over Private Relay. NEDNSProxyProvider was conspicuously not named in that statement, which is consistent with the broader "encrypted DNS bypasses DNS proxies" rule.

**Detection**: there is no public API to query Private Relay status directly. The practical signal is that our DNS proxy stops receiving flows for Safari traffic. Indirect detection via `NWPathMonitor` path attributes is unreliable.

**Response**: surface in dashboard ("⚠️ Private Relay is on; some Safari traffic bypasses WagerWall"). For Hardcore Mode, refuse to consider protections "active" until Private Relay is disabled — guide the user via deep link `App-Prefs:` to the relevant settings. Do NOT try to programmatically disable it — that would be hostile and Apple-rejection-bait.

The `NEPacketTunnelProvider` from §5.4 catches Private Relay too if we configure it to capture port 443 traffic to known Cloudflare/Apple Relay edge IPs and drop them — but that's an aggressive escalation and breaks Safari entirely. Better: let users opt into Hardcore Mode that requires Private Relay off as a precondition.

### 5.7 User installs a competing VPN

If the user installs a paid VPN app and enables it, that VPN may take precedence over our DNS proxy (depending on type — packet tunnel VPNs override DNS proxies).

**Detection**: `NEVPNManager.shared().connection.status` and enumerate active configurations.

**Response**: dashboard warning + partner notification. Hardcore Mode: invoke Instant Lockdown.

### 5.8 User uses Settings to disable Screen Time entirely

The Shortcuts Trap (§6.2) bounces them out of Settings. The PIN Vault (§6.3) means even if they reach the Screen Time setting, they need a PIN they don't have.

### 5.9 User rolls back device clock to bypass schedules

`store.dateAndTime.requireAutomaticDateAndTime = true` defeats this — the OS won't let the user manually set the clock backward while this is set.

### 5.10 User factory-resets the device

Nothing prevents this. Notifications to partner + email warning user about the consequences are the only response. This is the unfixable bypass; we accept it.

---

## 6. The Failsafe Layer

The failsafe layer is what turns a defeatable technical system into an **impulse-resistant** one. By itself, every Layer 1+2 mechanism above can be undone with 30 seconds of Settings tinkering. The failsafe makes each undo take 5 minutes, then require the accountability partner, then require a 48-hour wait — extending the bypass window past the lifetime of a typical gambling urge.

### 6.1 Instant Lockdown protocol

Triggered by §5.1 (DNS proxy disabled), §5.2 (Screen Time auth revoked — though this also breaks our enforcement, see below), §5.7 (rival VPN active), or any other detected bypass.

**Action**:
```swift
let lockdown = ManagedSettingsStore(named: .lockdown)
lockdown.shield.applicationCategories = .all(except: SharedContainer.essentialApps)
// essentialApps = user-selected during onboarding: Phone, Messages, Maps, Camera (≤6 apps)
```

Result: every non-essential app is shielded. The phone retains its safety/communication function but is useless for entertainment, browsing, social media, etc. — which removes the *reward* for the bypass attempt.

**Critical caveat**: Instant Lockdown only works if Screen Time auth is still granted. If the user revoked auth (§5.2), we have nothing to apply settings with. In that case the failsafe degrades to "notify partner aggressively + brick the WagerWall app's UI with a full-screen reinstall-protections prompt."

**Apple Store risk**: Apple's Guideline 2.5 (interfering with normal device operation) is a rejection risk. Mitigation:
- Lockdown must be **opt-in** at onboarding ("Hardcore Mode").
- Clearly explain in onboarding what triggers it.
- The lockdown UI in our app must include a one-tap "request unlock" flow (which routes to the 48hr cooldown, not instant relief).

### 6.2 The Shortcuts Trap

iOS Shortcuts can run "Personal Automations" that fire on system events — including "When app is opened: Settings." A user-built automation: *Trigger=When opening Settings → Action=Open WagerWall* bounces the user out of Settings within ~500ms.

Apple does not let third-party apps create or modify Shortcuts (the user must do it manually). Onboarding includes a step-by-step guide:

```
1. Tap "Open Shortcuts" (we deep-link to the Shortcuts app).
2. Tap Automation tab → + → Personal Automation.
3. Scroll to "App" → select Settings → "Is Opened" → Next.
4. Add Action → "Open App" → choose WagerWall → Next.
5. Toggle "Ask Before Running" off → Done.
```

**Verification step**: after the user creates it, our app prompts them to "Test it now — tap Settings to confirm" and waits for a return.

**5-Minute Leniency Window** for legitimate Settings access: in-app button "Pause Shortcuts Trap for 5 min." The actual mechanism is awkward — we cannot programmatically disable a user's Shortcut. Workarounds:

- **Option A (legitimate but ugly)**: walk the user through manually disabling the Shortcut Automation, set a 5-minute timer, prompt to re-enable.
- **Option B (better)**: a Shortcut step that checks for an `unlock_until` value in the iOS Clipboard or Files app and exits early if not yet expired — but this requires the user to set up a more complex Shortcut.
- **Option C (nuclear)**: don't offer leniency; require Settings access to come through the WagerWall app via a deep-link guidance flow that opens specific Settings panes (Apple supports this with `UIApplication.openSettingsURLString` and preference URLs).

**Recommendation**: Option C for v1. Most legitimate Settings access (WiFi, Bluetooth, notifications, etc.) can be deep-linked from in-app guidance. If the user genuinely needs Settings unrestricted, they can disable the Shortcut manually through Shortcuts app — this is itself a 60-second friction barrier that's good for impulse control.

### 6.3 PIN Vault and 48-hour cooldown

A 4-digit PIN generated cryptographically at onboarding. Stored only as an Argon2 hash in Supabase. The user is asked to:
- Write it on paper.
- Destroy the paper, OR give it to the accountability partner, OR throw it away entirely.

The PIN is required to:
- Disable the DNS proxy or Screen Time auth in our app's UI.
- Approve a Hardcore Mode downgrade.
- Recover from Instant Lockdown.

To retrieve the PIN, the user submits a "request unlock" → 48hr cooldown begins → PIN is delivered via email or to the accountability partner.

48 hours is chosen because:
- The peak of a gambling urge typically passes in 5–60 minutes (research on craving dynamics).
- A 24hr delay is sometimes too short for harder cases.
- Anything longer becomes punitive and risks app deletion.

The PIN provides **no protection against bypass via Settings** — only against bypass via our app's UI. The Settings-level bypass is what the Shortcuts Trap defends.

### 6.4 The mobileconfig profile (deletion resistance)

This is the deletion-resistance mechanism, layered on top of everything else.

**Build flow**:
1. App generates a `.mobileconfig` XML file with payloads:
   - `com.apple.networkextension` → references our `WagerwallDNSFilter` extension bundle.
   - Top-level `RemovalPassword` field set to a randomized 16-character string.
2. App posts the password to Supabase (or directly to the accountability partner via email).
3. App opens the .mobileconfig with `UIApplication.shared.open(url:)` → iOS shows it in Settings → user manually navigates to **Settings → General → VPN & Device Management** and taps Install (multi-step UX cliff added in iOS 12.2).
4. Profile is now installed; DNS filter persists across WagerWall deletion.

**Removal**: requires the password. Held server-side, released only after a 48hr cooldown initiated through the WagerWall app. Or held by the accountability partner.

**Confirmed working in 2025–2026 with caveats** (per Apple support docs and forum confirmations):
- Mobileconfig install via Safari download still works for unsupervised devices.
- `RemovalPassword` is honored for non-MDM profiles.
- **The user can wipe the device** to remove the profile. True non-removability requires *supervision* via Apple Configurator / DEP, which is enterprise-only and not viable for a consumer App Store app. Factory reset is the unfixable bypass.
- A Network Extension installed via raw mobileconfig (i.e., outside the App Store app's container) is **unusual** and may trigger App Review questions. We should be ready to justify it as the deletion-resistance mechanism for an addiction recovery app and cite Gamban / BetBlocker precedent.
- The multi-step manual install in Settings is a real UX cliff. Conversion through this flow during onboarding will be lower than ideal — design Hardcore Mode prompts to be clear and motivating.

### 6.5 Hierarchy of bypass response

| Bypass | First response | Escalation |
|---|---|---|
| App opened blocked app multiple times | Shield UI shown | DeviceActivityMonitor logs → partner notified after 3+ in 1hr |
| User toggled DNS proxy off | Push notification to partner + Instant Lockdown | App requires DNS re-enable to unlock |
| User revoked Screen Time auth | Aggressive partner notification | App's main UI replaced with reinstall-protections flow |
| User deleted WagerWall (Mode A only) | Heartbeat fails → partner email | Email to user citing relapse risk |
| User deleted WagerWall (Mode B installed) | Same + DNS filter still active | Profile removal still requires password (48hr cooldown) |
| User factory-reset device | Heartbeat fails permanently | Partner email |

---

## 7. End-to-End Flow Diagrams

### 7.1 First-run setup (Onboarding Phase 12)

```
┌───────────────────────────────────────────────────────────────┐
│                  WagerWall Onboarding                         │
├───────────────────────────────────────────────────────────────┤
│  1. Welcome + PGSI assessment                                 │
│  2. "Setup Protections" intro screen                          │
│  3. Request FamilyControls authorization → user approves      │
│  4. FamilyActivityPicker → user selects Casino category +     │
│     specific gambling apps                                    │
│  5. Apply ManagedSettingsStore.shield.applicationCategories   │
│  6. "Setup Website Blocking" → request NEDNSProxyManager      │
│     install → user approves                                   │
│  7. Background download bloom + radix DB to App Group         │
│  8. Optional: Hardcore Mode upgrade                           │
│     a. Generate 16-char removal password                      │
│     b. Generate .mobileconfig                                 │
│     c. Open in Safari → user accepts install                  │
│     d. Deliver password to partner / store hashed in Supabase │
│  9. Generate 4-digit PIN → user instructed to write/destroy   │
│ 10. Walk through Shortcuts Trap setup                         │
│ 11. Test: ask user to open Settings → verify Shortcut bounces │
│ 12. Confirm setup complete → land on Dashboard                │
└───────────────────────────────────────────────────────────────┘
```

### 7.2 Steady-state DNS query

```
   ┌────────┐      ┌─────────────────┐      ┌───────────────────┐
   │ Safari │─────▶│ mDNSResponder   │─────▶│ NEDNSProxyProvider│
   │  / app │      │ (system)        │      │ (our extension)   │
   └────────┘      └─────────────────┘      └────────┬──────────┘
                                                     │
                          ┌──────────────────────────┴───────┐
                          │                                  │
                          ▼ qname not in bloom (>99%)        ▼ qname might be
                  ┌──────────────┐                  ┌───────────────────┐
                  │ Forward to   │                  │ Confirm in radix  │
                  │ 1.1.1.1      │                  │ tree (SQLite)     │
                  └──────┬───────┘                  └────────┬──────────┘
                         │                                   │
                         │                   ┌───────────────┴───┐
                         │                   ▼ confirmed         ▼ false positive
                         │           ┌──────────────────┐ ┌──────────────┐
                         │           │ Synthesize       │ │ Forward to   │
                         │           │ NXDOMAIN reply   │ │ 1.1.1.1      │
                         │           └──────────────────┘ └──────┬───────┘
                         │                                       │
                         └──────────────┬────────────────────────┘
                                        ▼
                              ┌──────────────────┐
                              │ Response back    │
                              │ to mDNSResponder │
                              └──────────────────┘
```

### 7.3 Bypass attempt → Instant Lockdown

```
User toggles DNS proxy off in Settings
          │
          ▼
NEDNSProxyConfigurationDidChange fires in main app (via NotificationCenter)
          │
          ▼
AppDelegate.handleConfigChange()
  → manager.isEnabled == false
          │
          ▼
BlockingService.invokeInstantLockdown()
  → ManagedSettingsStore(.lockdown).shield.applicationCategories =
       .all(except: essentialApps)
          │
          ▼
SpringBoard re-evaluates next app launch → shields everything
          │
          ▼
HeartbeatService.flagBypass() → POST to Supabase
          │
          ▼
Edge function notify-partner → push + email + SMS to partner
          │
          ▼
WagerWall main UI replaced with "Protections compromised — re-enable DNS to unlock"
```

---

## 8. Implementation Phasing

Maps to CLAUDE.md's Phase 12 — replacing the single bullet with concrete sub-phases.

### Phase 12.1 — Screen Time foundation (no new entitlement risk)
- Replace `ScreenTimeAuthStepView` placeholder with real `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
- Build `BlockingService` protocol + impl wrapping `ManagedSettingsStore`.
- Integrate `FamilyActivityPicker` into onboarding (after assessment, before quit-date).
- Persist `FamilyActivitySelection` (Codable) to App Group `UserDefaults`.
- Apply default Casino category block on first picker save.
- `BlockingViewModel` + settings UI for managing blocked items.

**Estimated effort**: 4–6 days. Requires Family Controls entitlement applied to App ID first.

### Phase 12.2 — Shield extension targets
Add three Xcode targets (this is the big project-structure change):
- `WagerwallShieldConfiguration` → `ShieldConfigurationExtension`
- `WagerwallShieldAction` → `ShieldActionExtension`
- `WagerwallDeviceActivityMonitor` → `DeviceActivityMonitorExtension`

Each gets:
- Own bundle ID (`com.wagerwall.app.{Shield,ShieldAction,DeviceActivityMonitor}`)
- Family Controls entitlement
- App Group entitlement (`group.com.wagerwall.app.shared`)
- Own `Info.plist` declaring `NSExtension` config

Wire shield UI to WagerWall theme (purple, motivational copy from JSON in shared container).

**Estimated effort**: 3–5 days. Most of the time is fighting Xcode project structure (extension targets are notoriously fiddly with `PBXFileSystemSynchronizedRootGroup`).

### Phase 12.3 — NEDNSProxyProvider extension
- Add 4th extension target: `WagerwallDNSFilter`
- Bundle ID: `com.wagerwall.app.DNSFilter`
- Entitlement: `com.apple.developer.networking.networkextension` with `dns-proxy` value
- Implement `BloomFilter` (Swift, mmap-backed)
- Implement `RadixTreeDB` (SQLite-backed)
- Implement `DNSWire` parser (~200 lines; standard wire format)
- `DNSFilterProvider` glue
- Main app: `NEDNSProxyManager` install flow

**Estimated effort**: 8–12 days. The DNS parser and bloom filter are real engineering; the SQLite wrapper is straightforward; integration testing is painful (need to verify behavior on physical device, simulator doesn't fully run extensions).

### Phase 12.4 — Bloom filter pipeline
- Server-side build script (Python or TS Edge Function): pull StevenBlack hosts → normalize → compute bloom + radix → upload to Supabase Storage.
- Manifest endpoint (`/blocklist/manifest.json`).
- Client weekly background-fetch task using `BGTaskScheduler`.
- Atomic swap into App Group container.
- Trigger NE provider reload via `NEDNSProxyManager.saveToPreferences()`.

**Estimated effort**: 4–6 days.

### Phase 12.5 — Failsafe / Instant Lockdown
- Subscribe to `NEDNSProxyConfigurationDidChange` and `AuthorizationCenter` status changes.
- `lockdown` named `ManagedSettingsStore` configured with `.all(except: essentialApps)`.
- Onboarding step: pick essential apps (Phone, Messages, Maps, Camera as defaults).
- "Protections compromised" full-screen takeover UI.
- Dashboard tile showing failsafe status.

**Estimated effort**: 3–5 days.

### Phase 12.6 — Mobileconfig profile (Hardcore Mode)
- Server function to generate signed `.mobileconfig` (Apple's profile signing requires Apple Developer Profile cert; using PCKS#7 detached signature).
- App-side flow: generate password → POST to server for signing → receive signed profile URL → open in Safari → user accepts.
- Removal-password recovery flow with 48hr cooldown.

**Estimated effort**: 5–8 days. Profile signing is the unknown; may need a Supabase Edge Function with custom Deno crypto.

### Phase 12.7 — Shortcuts Trap onboarding
- Visual step-by-step flow with screenshots.
- Deep-link to Shortcuts app (`shortcuts://`).
- Verification: detect when user returns; prompt to test by opening Settings.
- Optional: include the legitimate Settings deep-link helper UI.

**Estimated effort**: 3–4 days.

### Phase 12.8 — DoH-blocking filter (NEFilterDataProvider)
- 5th extension target: `WagerwallDoHFilter`
- Inspect TLS SNI for known DoH endpoints; drop.
- Endpoint list shipped with bloom updates.

**Estimated effort**: 5–7 days. May be deferred to post-launch if DoH bypass turns out to be rare.

### Phase 12.9 — Packet-tunnel fortress (now MANDATORY due to DDR)

Per §5.4 confirmation: DDR auto-upgrade silently bypasses NEDNSProxyProvider whenever the user types 1.1.1.1 / 8.8.8.8 / 9.9.9.9 in WiFi settings. This makes the packet tunnel **non-optional** for credible blocking.

- 6th extension target: `WagerwallPacketTunnel`
- `NEPacketTunnelProvider` configured with `includedRoutes = [port 53, 853]` and selective port 443 capture for known DoH endpoints
- Forwards plain DNS (port 53) through our bloom-filter pipeline same as Layer 2
- Drops packets to known DoH endpoint IP ranges (Cloudflare 1.1.1.0/24, Google 8.8.8.0/24, Quad9, Mozilla, etc.)
- Enabled by default for all users (not just Hardcore Mode) — accepting the small battery cost for credible blocking

**Estimated effort**: 7–10 days. Significant complexity but unavoidable. Schedule alongside Phase 12.3 since both rely on the same bloom filter and DNS parser.

**Total Phase 12**: ~8–12 weeks of engineering, gated on entitlements.

---

## 9. Apple Entitlements & App Store Risk

### 9.1 Entitlements to apply for

| Entitlement | Required for | Approval timeline (2024–2025 anecdotal) |
|---|---|---|
| `com.apple.developer.family-controls` (Distribution) | All Layer 1 features | **Days to several months**, no progress visibility. Recent forum reports: some bundle IDs approved in 1 day; Shield Configuration Extensions stuck >2 weeks; full reviews 1+ month not unusual. **Each extension target needs its own approval.** |
| `com.apple.developer.networking.networkextension` (with `dns-proxy`, `packet-tunnel-provider`) | All Layer 2 features | Historically gated, justification-required; combined with Family Controls expect heightened scrutiny. |
| `content-filter-provider` (formal name for `NEFilterDataProvider`) | DoH SNI inspection | **iOS-side this is MDM-only.** Don't request for our use case — we'll hit it via packet tunnel instead. |

Sources: [Family Controls Entitlement Stuck thread](https://developer.apple.com/forums/thread/809208), [3+ weeks waiting](https://developer.apple.com/forums/thread/725036).

Apply for Family Controls and NetworkExtension on day one of the entitlement-blocking phase — they run in parallel. **Critical**: each extension target (ShieldConfiguration, ShieldAction, DeviceActivityMonitor, DNS Filter, Packet Tunnel) needs its own Family Controls / NetworkExtension entitlement approval. Submit all bundle IDs at once or risk staggered approvals dragging the timeline.

Apple's review is by humans and they want to see:
- A clear written justification (gambling addiction recovery is a sympathetic case — lead with this).
- Mockups / screenshots of intended UX.
- For NetworkExtension: explicit description of what data the extension processes and that it doesn't leave the device.
- Cite existing Gamban / BetBlocker precedent in the justification.

Common rejection patterns documented in forums:
- Vague justification ("for blocking adult content" generic).
- Intent to monetize blocking as a paid premium feature.
- Requesting `content-filter-provider` (MDM-only on iOS).
- Missing `NSExtensionPrincipalClass` in extension Info.plist.

### 9.2 App Store Review Guideline risk areas

| Guideline | Risk | Mitigation |
|---|---|---|
| **2.5.1** Apps must use Apple-blessed APIs | Low — we're using sanctioned APIs | N/A |
| **2.5.4** Apps that interfere with normal device operation | **Medium-High** for Instant Lockdown | Make Hardcore Mode opt-in with explicit consent screen; document the unlock path |
| **4.0** Design (UX quality) | Low | Standard design review |
| **4.5** Apps that mimic system functionality | Low — we're explicit about being a recovery tool | N/A |
| **5.1.1** Data collection disclosure | Medium — health-adjacent data | Clear privacy policy, App Store privacy labels accurate, no third-party analytics on sensitive events |
| **5.1.4** Kids Category considerations | N/A — 17+ rating | Set 17+ rating for gambling subject matter |

### 9.3 The Gamban precedent

Gamban, BetBlocker, and similar apps have shipped for years on the App Store using approximately this architecture (Family Controls + NetworkExtension + mobileconfig profile). This is precedent in our favor — Apple has approved this category. Citing existing precedent in the entitlement application can shorten review.

---

## 10. Open Questions / Validation Status

Verified 2026-04-28 via Apple DevForums research. Most items previously open are now closed:

### ✅ Closed (confirmed)

1. **NEDNSProxyProvider memory limit** — **15 MiB**, unchanged through iOS 26. Source: Quinn "The Eskimo!" memory-limits table ([DevForums #73148](https://developer.apple.com/forums/thread/73148?page=2)). Do not hardcode; test on real hardware.
2. **Per-network DNS bypass** — **CONFIRMED bypass via DDR auto-upgrade.** Setting WiFi DNS to 1.1.1.1 / 8.8.8.8 / 9.9.9.9 silently upgrades to DoH/DoT and bypasses our proxy. Phase 12.9 (packet tunnel) is now **mandatory**, not optional.
3. **DoH bypass** — **CONFIRMED, no Apple-blessed DNS-proxy mitigation.** Quinn: *"The system does not route secure DNS transactions to a DNS proxy server."* Mitigation requires `NEPacketTunnelProvider` + SNI-based dropping of known DoH endpoints.
4. **iCloud Private Relay** — confirmed bypasses encrypted DNS routing. NE filter providers and packet tunnel providers take precedence over Private Relay; NEDNSProxyProvider does not. Hardcore Mode requires Private Relay disabled as precondition.
5. **Mobileconfig profile install (2025–2026)** — still works for unsupervised devices via Safari download → manual install in Settings → General → VPN & Device Management. `RemovalPassword` honored. **User can wipe device** to remove. Multi-step UX cliff. NE-via-raw-mobileconfig may trigger App Review questions.
6. **`denyAppRemoval` self-applicability** — applies broadly to FamilyControls-managed apps, but **user can revoke FamilyControls auth in Settings**, voiding the restriction. Reports of over-application to other apps — verify before shipping.
7. **Family Controls + NetworkExtension entitlement timeline** — anecdotal range: days to several months. Each extension target needs its own approval. No published Apple statistics.

### 🟡 Still open (verify during implementation)

8. **NEDNSProxyProvider behavior with Private Relay alone** — Apple's statement names `NEFilterDataProvider` and `NEPacketTunnelProvider` as taking precedence; NEDNSProxy was conspicuously not named. File a TSI or test empirically with Private Relay on and no other DNS configured.
9. **Extension deployment with `PBXFileSystemSynchronizedRootGroup`** — the project's auto-discovered file structure may not play well with Extension/Embedded targets. May require restructuring or moving extension sources to legacy PBXGroup hierarchies.
10. **Profile signing requirement** — does Apple require PKCS#7-signed profiles to skip the "Unverified Profile" warning? Test with a development profile; if signed is required, build a Supabase Edge Function that signs profiles using a stored cert.
11. **Apple Sign-In requirement** — when the blocking layer ships, Apple Sign-In must also be live (currently missing per CLAUDE.md). Apple will reject a Family-Controls submission with Google Sign-In and no Apple Sign-In equivalent.
12. **iOS 26 `url-filter-provider`** — new NE type from WWDC25 Session 234. Currently appears MDM-only. If Apple opens to consumer apps, would replace much of our DoH bypass plumbing. Track for v2.
13. **App Review write-up** — draft the Family Controls + NetworkExtension justification text early. Lead with gambling addiction recovery angle and cite Gamban/BetBlocker precedent.

### 🔴 New constraints surfaced

14. **DDR auto-upgrade is a major design driver.** The §5.4 bypass is one tap away. This means the design promise of "lightweight DNS proxy + bloom filter" is incomplete on its own — we always need the packet tunnel for users serious about blocking. Either:
    - **Option A**: ship both the DNS proxy and packet tunnel from day one. Higher complexity, higher battery cost, but credible blocking.
    - **Option B**: ship DNS proxy only at launch (v1) with explicit limitation disclosure ("Manual DNS in WiFi settings will bypass WagerWall"); add packet tunnel in v2 as the deletion-resistance + bypass-resistance upgrade. Lower initial complexity, but accepts a known easy bypass.
    - Recommendation: **Option A** for the actual recovery use case. Users who would notice the battery difference are not the target market.

15. **Factory reset is the unfixable bypass.** No mitigation exists for a consumer iOS app. Document this clearly in onboarding so users understand the limit of protection. Pair with strong accountability-partner messaging.

### Source bibliography

- Apple DevForums: [Quinn — NE memory limits #73148](https://developer.apple.com/forums/thread/73148?page=2)
- Apple DevForums: [iOS 17 NE memory thread #747474](https://developer.apple.com/forums/thread/747474)
- Apple DevForums: [Quinn — encrypted DNS bypasses NEDNSProxy #729619](https://developer.apple.com/forums/thread/729619)
- Apple DevForums: [Matt Eaton — Private Relay precedence #689889](https://developer.apple.com/forums/thread/689889)
- Apple DevForums: [Apple Engineer — `denyAppRemoval` notes #729717](https://developer.apple.com/forums/thread/729717)
- Apple DevForums: [Family Controls Entitlement Stuck #809208](https://developer.apple.com/forums/thread/809208)
- Apple Docs: [NEDNSProxyProvider](https://developer.apple.com/documentation/networkextension/nednsproxyprovider)
- Apple Docs: [`denyAppRemoval`](https://developer.apple.com/documentation/managedsettings/applicationsettings/denyappremoval-swift.property)
- Apple Docs: [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- Apple Support: [Plan your configuration profiles](https://support.apple.com/guide/deployment/plan-your-configuration-profiles-dep9a318a393/web)
- Apple Support: [About iCloud Private Relay](https://support.apple.com/en-us/102602)
- WWDC25 Session 234: [Filter and tunnel network traffic with NetworkExtension](https://developer.apple.com/videos/play/wwdc2025/234/)

---

## 11. Summary

The architecture is **technically tractable**: Apple has shipped exactly the APIs needed (`FamilyControls`, `ManagedSettings`, `NEDNSProxyProvider`), the bloom filter math is well-understood and fits the memory budget with margin, the engineering effort is on the order of 6–10 weeks, and there's existing-app precedent (Gamban, BetBlocker) for App Store approval.

The architecture is **genuinely impulse-resistant**: technical layers + Shortcuts Trap + 48hr PIN cooldown + accountability partner + mobileconfig profile collectively extend any bypass attempt to tens of minutes minimum, with multiple human-in-the-loop gates. Determined attackers with patience can defeat it; that is the iOS reality. The goal is defeating the *impulse*, not defeating the *user*.

The architecture has **two genuine technical risks**: (1) Apple may have quietly tightened mobileconfig profile distribution for non-MDM apps, breaking the deletion-resistance story, and (2) per-network DNS or DoH may bypass our DNS proxy more aggressively than we expect. Both are testable up front before committing engineering. If both turn out badly, we fall back to Mode A only + aggressive heartbeat-based partner notification, which still delivers most of the recovery value.

The next concrete steps are:
1. Apply for both entitlements **today**.
2. Validate open questions §10.1–§10.5 against current iOS behavior using a test app.
3. Begin Phase 12.1 (Screen Time foundation) as soon as Family Controls entitlement clears.
4. Begin Phase 12.3 (NEDNSProxy + bloom filter) as soon as NetworkExtension entitlement clears.
