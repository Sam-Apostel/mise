# Mise / Menu Copilot — Roadmap

From the current scaffold → a public **TestFlight** beta (MVP) → a fully-featured 1.0.

Effort key: **S** ≈ <½ day · **M** ≈ 1–2 days · **L** ≈ 3–5 days. Sizes assume the
existing Swift-everywhere stack ([architecture](README.md)).

---

## Phase 0 — Where we are (done ✅)

- Shared `MiseShared` package: DTOs (`Dish`, `ParsedMenu`, `DietaryTag`, `Allergen`,
  `SpiceLevel`) + `DishFilter` logic, used by app and server.
- Vapor backend: `POST /v1/menu/parse` via Anthropic structured outputs, heuristic
  fallback, `/health`. Builds + tests green. Dockerised; `railway.json` ready.
- iOS app: all 7 Menu Copilot screens (Capture, Reading, Browse, Filters with live
  counts, Dish detail, My picks, smart empty state). On-device Vision OCR. Design
  system from the wireframes. Builds + tests green on the simulator.

**Not yet real:** backend isn't deployed, no dish images, no signing/TestFlight,
photo-library only (no live camera), descriptions translated by the LLM but unverified.

---

## Phase 1 — Production backend  ·  target: backend live on Railway

The app currently points at `localhost`. Get a real endpoint first; everything else
depends on it.

- [ ] Provision Railway project + service; set `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` **(S)**
- [ ] Deploy (`railway up`), confirm `/health` and a real `/menu/parse` call **(S)**
- [ ] Custom domain (e.g. `api.mise.app`) + TLS **(S)**
- [ ] Point the app at prod: per-config `MiseAPIBaseURL` (Debug=local, Release=prod) **(S)**
- [ ] Basic server hardening: request rate limiting, CORS, structured logging, request-id **(M)**
- [ ] Cost guardrails: max OCR length, per-IP throttle, model cost logging **(S)**

**Exit:** a Release build of the app parses a real menu against the deployed API.

---

## Phase 2 — MVP feature completeness  ·  the bar for "worth testing"

The pitch is *scan → rich filters → images of dishes*. MVP must deliver all three.

- [ ] **Live camera capture** — `VNDocumentCameraViewController` (or AVFoundation) in
      addition to the photo picker; auto-crop the menu **(M)**
- [ ] **Dish images (v1)** — server-side enrichment: **AI-generated** images keyed by
      dish name (+ cuisine), generate-once → review → cache on CDN, populate
      `Dish.imageURL`, fall back to the existing placeholder. **(L)**
  - Decision made — see [docs/research/dish-images.md](docs/research/dish-images.md):
    fallback chain **Spoonacular → Pexels → Pixabay → AI-gen (labeled) → placeholder**,
    cached by `dishName+cuisine`. Real photos first (Spoonacular's ToS uniquely allows
    storing the image URL); AI generation (Gemini/FLUX.2) only for the long tail, labeled
    "AI · illustrative". Avoid web image search + Places/Yelp (ToS forbid caching).
  - Adds a `Dish.isAIGenerated` field (schema change) to drive the label.
- [ ] **OCR robustness** — multi-photo / long menus, low-light, angled shots; show a
      "retake" path when confidence is low **(M)**
- [ ] **Loading & error states** — network failure, empty menu, timeout, offline copy **(S)**
- [ ] **Recent scans** — local persistence (SwiftData) so a menu survives app restart **(M)**
- [ ] **Settings** — preferred language for translations, default currency, clear data **(S)**
- [ ] Empty/edge polish on My picks, Filters, Dish detail **(S)**

**Exit:** a first-time user can scan a real restaurant menu, see images + working
filters, build a picks list, and reopen the app to find it still there.

---

## Phase 3 — Ship to TestFlight  ·  🎯 active TestFlight beta

This is the headline milestone. Most items are one-time setup.

### App Store Connect & signing
- [ ] Apple Developer Program enrollment (if not already) **(S)**
- [ ] Register App ID `be.apostel.mise`; set `DEVELOPMENT_TEAM` in `project.yml` **(S)**
- [ ] Create the app record in App Store Connect **(S)**
- [ ] Signing: automatic signing for dev, manual/cloud cert for distribution **(M)**

### Build & compliance
- [ ] **App icon** (replace the empty `AppIcon.appiconset`) + polished launch screen **(M)**
- [ ] **Privacy manifest** (`PrivacyInfo.xcprivacy`) — camera, photo library, any network
      domains; confirm usage strings **(S)**
- [ ] Export-compliance answer (uses only standard HTTPS → typically exempt) **(S)**
- [ ] Archive + upload pipeline: `xcodebuild archive` → `xcrun altool`/`notarytool`
      or Xcode Cloud / Fastlane `pilot` **(M)**

### TestFlight
- [ ] First build to TestFlight; pass Beta App Review **(M)**
- [ ] Internal testers (yourself + a few), then a small external group **(S)**
- [ ] Feedback loop: TestFlight feedback + a lightweight in-app "report a bad parse" **(S)**

### Quality gate before inviting testers
- [ ] Crash reporting (Sentry/Crashlytics or MetricKit) **(S)**
- [ ] CI: GitHub Actions running `make test` on push (shared + server + app) **(M)**

**Exit:** external testers are installing builds from TestFlight and you're collecting
real menus + feedback.

---

## Phase 4 — Beta hardening  ·  iterate toward 1.0

Driven by TestFlight feedback; expect parsing quality to dominate.

- [ ] **Parse quality** — eval set of real menus; measure dish recall + tag accuracy;
      tune prompt/schema; consider a correction UI that feeds examples back **(L)**
- [ ] **Translation quality** — verify bilingual descriptions; handle non-Latin scripts;
      let users switch target language live **(M)**
- [ ] **Image quality** — relevance ranking, de-dupe, attribution/licensing, moderation **(M)**
- [ ] Accessibility: Dynamic Type, VoiceOver labels on pills/rows, contrast audit **(M)**
- [ ] Performance: large-menu scroll, image loading/caching, OCR on older devices **(M)**
- [ ] Analytics: funnel (scan → browse → pick), opt-in, privacy-first **(S)**
- [ ] Localize the UI chrome (not just dish content) for first launch markets **(M)**

**Exit:** parse + image quality good enough that the app is genuinely useful on most
menus; crash-free sessions high; ready for public App Store review.

---

## Phase 5 — Fully featured 1.0 (App Store) and beyond

Public launch + the features that make it sticky.

- [ ] App Store listing: screenshots, description, keywords, privacy nutrition labels **(M)**
- [ ] Public App Store review + release **(M)**
- [ ] **Personalization** — save dietary profile (allergies, diet) so filters pre-apply **(M)**
- [ ] **Share & collaborate** — share a menu/picks link; let the table vote on dishes **(L)**
- [ ] **Translate menu in-place** — overlay translation on the original photo **(L)**
- [ ] **Dish intelligence** — "what's this?" explainer, typical ingredients, pairings **(M)**
- [ ] **History & favorites** — revisit past restaurants, favorite dishes across visits **(M)**
- [ ] **Offline mode** — cache last menus; queue scans when offline **(M)**
- [ ] **Restaurant context** — optional reviews/ratings, hours, location enrichment **(L)**
- [ ] Optional account sync (iCloud/CloudKit) across devices **(L)**
- [ ] iPad / landscape layouts; widget for recent menu **(M)**

### Stretch / exploratory
- Real-time camera translation (live overlay), Apple Intelligence on-device parsing to
  cut backend cost, menu price analytics, group ordering, reservation hooks.

---

## Cross-cutting (continuous)

- **Testing** — keep `make test` green; add snapshot tests for screens, server
  integration tests with a mocked Anthropic.
- **Observability** — server logs/metrics on Railway; client crash + funnel analytics.
- **Security/privacy** — keep OCR on-device; never log menu images; rotate API keys;
  minimize data retention.
- **Cost** — monitor Anthropic + image-API spend per scan; cache aggressively.

---

## Suggested order

1. Phase 1 (backend live) →
2. Phase 3 setup items **in parallel** with Phase 2 (camera, images, persistence) →
3. First TestFlight build as soon as Phase 2 core + Phase 3 setup are done →
4. Iterate Phase 4 from feedback →
5. Phase 5 for public 1.0.

The fastest path to **"active TestFlight"** is: deploy backend → app icon + signing →
camera + minimal images + error states → archive → TestFlight. Everything else can
ship as TestFlight updates.
