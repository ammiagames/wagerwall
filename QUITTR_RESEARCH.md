# Quittr Research — Feature Benchmark for WagerWall

Cross-referenced synthesis from 17 parallel research agents (May 2026). Quittr is the closest-analog success in the addiction-recovery app category — porn rather than gambling, but the same product surface (streak + panic button + community + blocker + AI). This document distills what makes Quittr work, what to copy, what to avoid, and where its gaps create greenfield for WagerWall.

---

## Executive Summary

**Quittr's success is not technical depth.** Its blocker is a shallow `NEDNSProxyProvider`-style local VPN (no Family Controls, no app-launch shielding, no deletion resistance). Its AI coach "Melius" is mediocre and rate-limited. Its CBT content is in-house, AI-augmented, and cites no clinicians. Its data security failed publicly — a March 2026 misconfigured Firebase exposed 600K user records including ~100K self-identified minors.

**What Quittr does exceptionally** is convert TikTok views → installs → subscriptions through a tightly choreographed funnel:

1. A 12-page personalization quiz with **99% completion rate** that culminates in a calibrated "dependency score" (manufactured to read above-average even for moderate users).
2. A **hard cascading paywall** (80%-off countdown OTO → standard pricing → 3-day trial salvage → $20 annual exit-discount) hitting a documented **25% install-to-paid conversion**.
3. Retention via **streak loss aversion** (Life Tree visualization wilts on relapse) plus an emotionally violent **Panic Button** (front-camera + flashing red text + haptics) plus an **anonymous peer community** with leaderboard.
4. **Influencer-led TikTok GTM** — $3K seed → $37K month one; one creator video = $100K in 65 hours.

Reported scale: $250K MRR within 4 months of launch, $500K MRR by early 2026, 1.5M downloads, 4.7 stars on ~31K App Store ratings, 120+ countries, fully bootstrapped. Founders Alex Slater (CEO), Chris Slater, Connor McLaren, Peter Adair.

**For WagerWall**, the strategic implication is that the bar in the gambling-recovery category is dramatically lower than in porn-recovery. The strongest gambling competitor (Gamban, £25/yr) is a blocker with 2014 UI; BetBlocker is free and charity-run with dated UX; GamCare is a clinical website with a thin app. **No "Quittr of gambling" exists yet.** WagerWall can run Quittr's playbook against weaker incumbents while doing the technical-substance things Quittr deliberately punted (Family Controls + bloom-filter NEDNSProxy + deletion-resistant `.mobileconfig` with partner-held removal password).

---

## Tier 1 — Revenue-critical (do these or don't ship)

### 1. The 12-page onboarding quiz with a manufactured dependency score
- **Mechanic**: 10–12 calibrated questions (frequency, escalation, age of first exposure, emotional triggers, spend) → percentage score reflected against a "national average" baseline tuned to make most users score "above average."
- **Numbers**: 99% quiz completion (Mixpanel), ~25% install-to-paid conversion (founder-attributed). One App Store reviewer answering "rarely use porn" still got 39% above average — the score is the conversion lever.
- **Sequence**: quiz → dependency score reveal → symptom selector (mental/physical/social/faith) → educational carousel → goals selection → social proof wall → personalized plan teaser ("You will quit by [date]") → benefit deep-dives → countdown discount → paywall → sign-to-commit pledge (signature pad) → checkout.
- **WagerWall move**: Lift PGSI from `Wagerwall/Wagerwall/Resources/Assessment.json` out of `Views/Profile/AssessmentView.swift` and wire it into `OnboardingViewModel` as the first paywall lead-up. Today the VM only has `.welcome` and `.screenTime`; insert `.assessment → .symptoms → .goals → .quitDate → .signPledge → .plan → .paywall`. Calibrate the comparison baseline below typical PGSI answers so most users score "above average." Add a non-medical disclaimer.

### 2. Cascading hard paywall: countdown OTO → standard → free-trial salvage
- **Three paywalls in sequence**: (a) "80% off, 5-minute countdown" One-Time Offer; (b) on dismiss, full-pricing page with social proof ("1.7M men"); (c) on second dismiss, 3-day free trial. On exit-attempt, drop yearly $20 ($45 → $39.99 → effective ~$25/yr).
- **Pricing**: $12.99/mo, $39.99–$45/yr, $19.99 lifetime as upsell capture (multiple geo-A/B SKUs from $9.99–$14.99 monthly, $19.99–$29.99 annually).
- **Founder confirmed freemium tested and abandoned.**
- **WagerWall move**: ship monthly + annual, plus a $49 lifetime upsell. **Skip the lifetime SKU long-term** — it's the largest source of refund disputes ("Lifetime didn't unlock after reinstall") in Quittr's review corpus.

### 3. Streak counter as identity hook
- **The single most-praised feature in App Store reviews.** *"Seeing the streak grow every day is way more motivating than I expected. It makes you think twice before ruining the progress."*
- **#1 bug-driven churn event** when streaks reset unexpectedly — multiple 1-stars are pure "my streak got reset."
- **Soft mechanics**: distinguish "slips" from full relapses; 72-hour recovery timer post-relapse frames first 3 days as a discrete sub-goal.
- **WagerWall move**: WagerWall's server-side `user_streaks` is correct. Treat `current_streak_days` as append-only with an audit log before adding any client-side mutations. Surface "longest streak ever" prominently — Quittr under-emphasizes personal-best.

### 4. Panic Button with sensory-overload urge interruption
- **The flow**: tap → black screen + flashing red/white text + haptic vibration + front camera turns on with motivational text overlaying the user's own face (*"What's your excuse this time?"* / *"You're better than this. Look at yourself."*) → routes into breathwork + Melius AI + motivational reminders + community.
- **Co-founder explicit framing**: *"The big thing is shame."* Universally cited as Quittr's "earns its keep" feature.
- **WagerWall move**: Copy the *interruption mechanic*; **swap shame for money-loss reframing** (show user's logged annual spend, savings goal, "amount lost to gambling this year"). Avoid the literal mirror — gambling-disorder populations have higher comorbid suicidality. Add a 10–20 min urge-surfing timer (gambling cravings build over hours, unlike porn's acute spikes). Wire `notify-partner` into the panic button directly, not just `disable-protection`. Replay the user's onboarding "why I'm quitting" reasons via `MotivationalCardView`. Auto-prompt `LogUrgeView` after `BreathingExerciseView` instead of leaving it as a separate dashboard card. Replace the hardcoded `intensity = 8` in `PanicButtonViewModel.logAndComplete` with a post-urge slider.

### 5. Anonymous community feed + streak leaderboard
- **~500 daily posts**, pseudonymous handles (e.g., `u/Matt`, `u/Lucas`), day-counter beside each name. 28-day cohort challenge.
- **The feature users actually credit for quitting** (Reddit/sentiment + reviews) — not AI, not blocking. Ed Latimore: *"if the app only came with this feature, it would be better than every other porn blocking app on the market."*
- **External Telegram** (~6,100 men) extends the in-app feed.
- **Privacy caveat**: Quittr's UI was pseudonymous, but the data layer was not — Firebase breach exposed mappings. Pseudonymity in UI ≠ safe storage.
- **WagerWall move**: ship a real community feed; high-leverage and cheap. Keep ranking on streak length, not dollars — a "biggest amount saved" leaderboard could shame people. Lock down Supabase RLS *before* mood/urge/journal logs ship to TestFlight.

---

## Tier 2 — Retention engine

### 6. Life Tree gamification visualization
- Virtual plant grows seed → sapling → mature tree as streak extends; relapse visibly destroys it. Designed as the share-screenshot hero.
- Loss aversion mechanic: a 60-day tree is *physically destroyed* on relapse — abstract progress becomes a tangible asset to defend.
- **WagerWall move**: Build a **"Bankroll Tree" / "Vault"** — visualize money saved (`daily_gambling_spend × days_clean`) accumulating as something destroyable. Gambling's natural advantage over porn: savings are quantifiable in a way dopamine recovery isn't. **Skip the brain-rewiring metaphor** — gambling neuroscience is weaker than porn's; would invite scrutiny Quittr survives only because their target audience *wants* to believe.

### 7. Achievement Orbs — 12-tier mystery-threshold badge system
Sprout → Enlightenment → Ascendant → Guardian → Fortress → Momentum → Pioneer → Nirvana → Sovereign → Harbinger → Transcendent → Luminary. Day-thresholds undisclosed — variable-reward mechanic that keeps users playing past obvious milestones.

### 8. AI Coach "Melius" — rate-limited chatbot
- Reviews mixed-to-negative (*"completely misses the mark,"* *"least useful"*). Marketing surface (TikTok demo asset), not the retention driver.
- Daily message cap on free tier (exact number undocumented).
- Underlying model **not disclosed publicly** by Quittr.
- **WagerWall move**: ship parity but don't bet the company. **Differentiation lane Quittr left open**: wire AI handoff *from* the Panic Button with explicit context (just-logged urge intensity, last bet amount, bankroll status, top-3 triggers, recent CBT module). Ground prompts in CBT modules so it's a tutor, not a generic empath. Be the first in this category to disclose the model ("Powered by Claude") as a trust signal. Gambling-specific guardrails: never give odds/strategy advice, refuse to validate "one last bet" reasoning, escalate to 1-800-GAMBLER on suicidal/financial-ruin language.

### 9. Daily pledge → 24h check-in notification
The only push pattern with documented retention lift. User commits ("I won't relapse today"); 24h later, app pushes "How did it go?"

### 10. Bundled CBT lesson library
- **4 modules × 5 lessons = ~20 short lessons**: Addiction & Myths / Health Effects / Quitting Benefits / Recovery Strategies.
- Format mix: ~60% text, ~20% interactive (challenges, Melius, journaling), ~15% audio (meditations), ~5% video.
- **No clinical credentials cited.** Influencer endorsers (Jeremiah Jones, Shannon Malik, Caleb Hammelt, Bryce Crawford), not therapists. Founder admitted to Dazed: *"still working on some of the legitimising stuff."*
- **WagerWall move**: WagerWall's 8-module bundled-Swift plan in `Wagerwall/Wagerwall/Content/` already exceeds Quittr's structure. Finish modules 4–8 with a named clinician credit per lesson. **Gambling has DSM-5 recognition (porn doesn't)** — partner with one peer-reviewed study and you outrank every gambling app on Google forever. Cite PGSI, GA, SMART Recovery.

---

## Tier 3 — Table stakes

### 11. Content blocker (DNS-level, VPN-style)
- Quittr uses an `NEDNSProxyProvider`-style local VPN profile — *not* Apple's Family Controls. Cross-browser coverage but **no app-launch blocking**, **no `denyAppRemoval`**, **no partner-held password**, **doesn't survive deletion**.
- Marketed as #1 feature; technically the weakest layer.
- Claims 3M+ blocked sites, including incognito coverage.
- **WagerWall move**: this is your **biggest moat**. Phase 12 in `CLAUDE.md` (Family Controls + bloom-filter `NEDNSProxyProvider` + `.mobileconfig` with partner-held removal password) is strictly stronger than anything Quittr ships. Apply for the entitlements; this is the single most-defensible technical differentiator. See `BLOCKING_ARCHITECTURE.md`.

### 12. 30-Day Challenge cohort ring
Time-boxed leaderboard challenge. For WagerWall: 30-day or 90-day "no-bet" challenge maps directly.

### 13. Two-library motivational notifications: Motivation + Side Effects
- Random daily push, user picks tone (encouragement vs aversion).
- Default 8 PM (matches the smoking-cessation Quittr precursor RCT cadence).
- **WagerWall move**: "Reasons to Quit" (encouragement) + "Cost of Relapse" (financial aversion) libraries, user picks tone, default 8 PM.

### 14. Relapse Reflection Journal with bifurcated tone
- **Stern at the Panic Button** ("This is a real threat. Don't screw this up.") → **soft post-relapse** (*"It's not a reset to zero, it's a checkpoint for awareness."*).
- Captures: time of relapse, emotional state, isolation level, triggering content. AI coach generates "concrete change to reduce repeat chances."
- Recovery Timeline (24h/48h/72h clarity-and-energy rebound markers).
- **WagerWall move**: add a **financial-damage reflection step** — amount lost, payment method (debit/credit/crypto), platform, forward-looking *"What does this mean for rent / groceries / debt?"* prompt. Pair with explicitly non-judgmental framing ("This is data, not a verdict") to avoid the chase-betting shame spiral.

### 15. Trigger taxonomy (External vs Internal)
- Internal includes *positive* emotions (excitement, joy) — **critical for gambling: gamblers relapse on highs as often as lows.**
- **WagerWall extensions**: promo notification, sports event, friend group, alcohol, boredom, chasing prior loss, win-streak euphoria.

### 16. Influencer-led TikTok GTM (not a product feature, but inseparable)
- $3K seed → $37K month one. One Jeremiah Jones video = 9.9M views, $40K in a day, $100K in 65 hours, 217x ROI on a $100 meme-account placement.
- Brand TikTok (`@quittr.app`) is small (~5.5K followers); growth comes from **paid creator seeding**: $2–3 CPM, 20% upfront / rest on App Store payout, view-count guarantees.
- Targeting order: Christian creators → fitness → self-help.
- **WagerWall audience tribes to test**: men in recovery / sober-curious; personal-finance/FIRE TikTok; post-Sunday-loss sports-betting losers ("I lost $X this Sunday"); faith communities (Catholic/Christian gambling recovery is sizable).
- **Compliance gotcha**: gambling-recovery keywords are restricted on Meta. Lean harder on creator seeding + X memes + YouTube long-form ("I lost everything betting" interview content).

### 17. Affiliate program (30% recurring + 10% second-tier)
Easy structural copy. *"1000 installs = $4000, you take $1200."*

---

## Tier 4 — Low-impact / mostly cosmetic

- **Single basic breathing exercise** — universally criticized; ship 3+ patterns to clear Quittr's bar.
- **Telegram external community** (~6,100 members) — works but secondary to in-app feed.
- **Sign-to-commit pledge screen** (signature pad in onboarding) — small lift; copyable.
- **Founder-as-face-of-brand presence** on TikTok/YouTube — cheap authenticity signal.

---

## Things to NOT copy

| Anti-pattern | Why |
|---|---|
| **Lifetime SKU** | Largest source of App Store refund disputes ("Lifetime didn't unlock after reinstall"). Monthly + annual only after a brief launch test. |
| **Guilt-trip cancellation pop-ups** ("are you sure you want to give up on yourself?") | Repeatedly named in App Store reviews as the moment users soured. |
| **"Brain rewiring" pseudoscience** | Gambling neuroscience is weaker than porn's. Cite PGSI/CBT primary literature instead. |
| **Shame-as-UX** | Gambling-disorder populations have higher comorbid suicidality. Reframe to financial loss, not personal humiliation. |
| **Default-permissive Firebase / lax data security** | Quittr's 600K-user breach (including ~100K self-identified minors) is a national-press cautionary tale. Lock Supabase RLS *before* TestFlight. Hash + aggregate blocked-attempt URLs server-side; never store raw values. |
| **Promising features you don't ship** | Quittr's "Accountability Partner Integration" appears to be marketing copy without a real implementation; competitor takedown articles exploit this. WagerWall's `AccountabilityPartnerViewModel` is already scaffolded — finish it before marketing it. |
| **AI-generated CBT lessons as the product** | Users smell it instantly ("seem AI generated"). WagerWall's hand-authored `Content/AppContent.swift` is already the right call — finish modules 4–8 with clinician credits before adding any LLM-generated lessons. |
| **Unstaffed support inbox** | Auto-replies that say "sent to senior support" with no follow-through generate more 1-stars than the bugs. Even a 48-hour SLA beats Quittr. |

---

## Greenfield gaps Quittr left open

| Gap | WagerWall move |
|---|---|
| No Lock Screen widget / Live Activity | Streak + $ saved Live Activity |
| No re-engagement loop for silent users | "We miss you" 3 / 7 / 14-day push ladder |
| No crisis hotline in panic flow | Surface 1-800-GAMBLER + 988 in `CrisisResourcesView`, promote into panic flow |
| No real accountability partner monitoring | `AccountabilityPartnerViewModel` + `notify-partner` already scaffolded — finish it |
| No app-launch blocking, no deletion resistance | Family Controls + `.mobileconfig` with partner-held removal password (Phase 12) |
| No quantitative recovery dashboard | $$$ saved counter (live-ticking, big-type) + GitHub-style 365-day clean calendar + percentile-vs-cohort + shareable "Day 47 · $1,420 saved · 38 urges resisted" 9:16 export card |
| No clinical credibility | Cite PGSI, GA, SMART Recovery, named clinician per lesson; partner with one peer-reviewed study |
| No regulated-industry distribution | Sportsbooks must surface "responsible gambling" tools in 30+ US states — partner inclusion = free CAC channel with no porn-space analog |
| No pattern-detection insights | Quittr advertises "key patterns" but doesn't surface them. Ship explicit weekly insight cards ("3 of your last 4 urges happened Sunday evening") — gambling has clearer time/event structure than porn |
| No in-the-moment AI from Panic Button | Wire `Melius`-equivalent into the panic flow with full context injection |

---

## Top 5 priority shippable items

1. **Re-enable auth routing.** `Core/AppState.swift:30` hardcodes `rootScreen = .main` behind a TODO. Wire PGSI from `Resources/Assessment.json` into onboarding as the dependency-score reveal that opens the paywall.
2. **Cascading paywall** with OTO countdown → standard → trial — gate Phase-12 blocking + AI coach + advanced analytics behind it. Skip lifetime tier in launch.
3. **Bankroll Tree / Vault visualization** tied to `daily_gambling_spend × days_clean`, plus a shareable export card.
4. **Apply for Family Controls + Network Extension entitlements** so Phase 12 — your real moat — can ship. See `BLOCKING_ARCHITECTURE.md`.
5. **Finish `send-push` JWT signing.** Without it, partner notifications can't deliver, which kills the one accountability differentiator gambling has over porn.

---

## Founder & corporate context

- **Quittr, LLC** — bootstrapped, anti-VC positioning ("$140K in 3 months, 90% margin, 100% reinvested").
- **Co-founders**: Alex Slater (CEO, ~19 at launch, San Francisco, self-taught coder, met Connor via YC Co-Founder Matching), Chris Slater (Product/Design), Connor McLaren (Operations), Peter Adair (Marketing).
- **Sister app**: Reset (`com.quittrapp.reset`, App Store ID 6755929687) — broader habit/discipline app from same team.
- **Public scale claims** (founder/PR-sourced, treat as marketing): $40K month one → $250K MRR month four → $500K MRR by early 2026; 1.5M downloads; 4.7 stars on ~31K App Store ratings; 120+ countries; claimed 41% one-year abstinence rate (no published methodology).

### The breach — non-negotiable cautionary tale
March 2026: 404 Media reported Quittr's misconfigured Firebase had exposed ~600K user records — including masturbation logs, journal entries, "triggers," and ages — with ~100K self-identified as minors. Multiple security researchers reportedly warned the founders for months and were ignored. Co-founder Connor reportedly told 404 Media to "have a good day" and hung up. Class-action notice exists at claimdepot.com.

For WagerWall, gambling-loss journal entries + bet history + debt amounts are the same severity-class of data. **RLS-hard, encrypted-at-rest, minimal PII in heartbeats, never store identifiable bet content beyond strict need.**

---

## Competitor landscape — gambling space

The bar is dramatically lower than the porn-recovery category. From the comparative academic review ([PMC10919356](https://pmc.ncbi.nlm.nih.gov/articles/PMC10919356/)): only 14 unique problem-gambling-specific apps exist across both stores; only 36% rated "best-rated"; users widely skeptical of effectiveness.

| App | What it is | Pricing | Notes |
|---|---|---|---|
| **Gamban** | Blocks 40,000+ gambling sites/apps, anti-removal hardening | £24.99/yr / £2.49/mo | Most polished. Self-reported 71% 12-mo abstinence. VPN-bypassable. |
| **BetBlocker** | Free blocker, 90,000+ sites, 5-year lockout, anonymous | Free (charity-funded) | Best free option; reports of casino apps still accessible |
| **GamCare app / GameChange** | UK helpline + CCBT course w/ therapist contact, peer forums | Free (charity) | Clinical credibility; UK-centric; not a slick consumer app |
| **Stay Clean / I Am Sober / Nomo / Gambling Addiction Calendar** | Generic sobriety counters with gambling category | Free + IAP ($9.99/mo on IAS) | Streak/panic-text only, no CBT, no blocking |

**No "Quittr of gambling" exists yet.** Every Quittr advantage transfers cleanly. Add Family Controls blocking + financial framing + clinical credibility and WagerWall outranks all of these.

---

## Source agents (May 2026 research)

| Agent | Focus | ID (for SendMessage follow-up) |
|---|---|---|
| 1 | iOS App Store positive reviews & advertised features | `a0817e02aba38c7c8` |
| 2 | iOS App Store negative reviews & cancellation reasons | `ae252df1eda689c9a` |
| 3 | Pricing tiers, paywall placement, conversion tactics | `a4c4aefc68123ef0e` |
| 4 | Onboarding flow (39 screens, 12-page quiz, sign-to-commit) | `a84b5fe5feacc42d5` |
| 5 | Streak system, Life Tree, 12 Orb tiers, recovery timeline | `aee4bcb86fac077c8` |
| 6 | Community feed, leaderboard, accountability features | `a0883263c463e2947` |
| 7 | Educational content / curriculum / clinical credibility | `a88986bf108e95b87` |
| 8 | Panic Button & urge-management flow | `aa8ef12436c8146d0` |
| 9 | Blocking technology — DNS proxy vs Family Controls | `aeced1068c494799f` |
| 10 | Notifications, widgets, engagement loops | `a8ade2ff4fa541308` |
| 11 | AI features — Melius coach, rate limits, model | `ab3cbc1e55bd1950e` |
| 12 | Dashboard layout & data visualization | `acdaf665cceac0053` |
| 13 | Reddit / forum sentiment (App Store substituted — Reddit blocked) | `aa69f1de428fbd5f2` |
| 14 | Marketing & TikTok / influencer GTM | `abc676587a8118a4a` |
| 15 | Founder & brand origin story; data breach | `aa2d53e6c68b39109` |
| 16 | Direct competitor comparison (porn + gambling) | `a4a4b8ff650376255` |
| 17 | Relapse handling, journaling, reflection | `ab63310c2ecb8f3c5` |

### Primary sources cited across agents
- Quittr official: [quittrapp.com](https://quittrapp.com/), [join.quittrapp.com](https://join.quittrapp.com/) (live onboarding funnel), [App Store listing](https://apps.apple.com/us/app/quittr-break-free-now/id6532588521)
- Founder interviews: [BoringCashCow](https://boringcashcow.com/interview/interview-with-the-founder-of-quittr), [LA Weekly](https://www.laweekly.com/from-broke-to-bold-how-alex-slater-built-quittr-into-a-1m-digital-wellness-powerhouse-at-19/), [TechTimes](https://www.techtimes.com/articles/310068/20250420/bootstrapped-revolution-why-quittrs-anti-vc-approach-disrupting-mental-health-tech.htm)
- Growth teardowns: [Startup Spells $250K MRR breakdown](https://startupspells.com/p/porn-addiction-app-quittr-250k-mrr-4-months), [No-Code Builders](https://no-code-builders.beehiiv.com/p/this-app-reached-260k-mrr-in-3-months), [ScreensDesign](https://screensdesign.com/showcase/quittr-quit-porn-now)
- Press: [The Free Press](https://www.thefp.com/p/how-to-de-addict-gen-z-from-porn), [Dazed](https://www.dazeddigital.com/life-culture/article/70018/1/quitting-porn-addiction-self-improvement-young-men-quittr-app), [Inc.](https://www.inc.com/maria-jose-gutierrez-chavez/this-gen-z-founder-wants-young-men-to-stop-watching-porn/91312748)
- Hands-on review: [Ed Latimore](https://edlatimore.com/quit-porn-quittr-app-review)
- Data breach coverage: [404 Media](https://www.404media.co/viral-quittr-porn-addiction-app-exposed-the-masturbation-habits-of-hundreds-of-thousands-of-users/), [404 Media follow-up](https://www.404media.co/multiple-hackers-warned-anti-porn-app-quittr-about-security-issue-for-months/), [Cybernews](https://cybernews.com/privacy/app-quit-porn-exposed-masturbation-habits-600000-users/), [Techlicious](https://www.techlicious.com/blog/quittr-porn-addiction-app-leaked-what-users-say-they-watch/)
- Competitor benchmarks: [Canopy NoFap roundup](https://canopy.us/blog/best-nofap-apps/), [Gamban](https://gamban.com/), [BetBlocker](https://betblocker.org/), [GamCare](https://www.gamcare.org.uk/), [PMC review of gambling apps](https://pmc.ncbi.nlm.nih.gov/articles/PMC10919356/)
