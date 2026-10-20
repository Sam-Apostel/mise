# Mise

Scan a restaurant menu, get a structured, **filterable** list of dishes with rich
dietary filters and (eventually) images of each dish.

> Status: greenfield infrastructure. The full pipeline works end-to-end; visual
> design and wireframes land later.

## How it works

```
┌────────────────────┐      OCR text       ┌──────────────────────┐
│  iOS app (SwiftUI) │ ──────────────────▶ │  Vapor server        │
│  • Vision OCR      │                     │  • LLM menu parsing   │
│  • rich filters    │ ◀────────────────── │    (Anthropic API)    │
│  • dish list/images│   structured menu   │  • heuristic fallback │
└────────────────────┘                     └──────────────────────┘
            ▲                                          ▲
            └────────── MiseShared (DTOs) ─────────────┘
```

- **On-device OCR** — the app uses Apple's Vision framework, so menu photos never
  leave the device; only recognised text is sent to the backend.
- **Server-side parsing** — the Vapor backend turns raw text into structured dishes
  (name, course, price, dietary tags, ingredients) using the Anthropic Messages API
  with structured outputs. With no API key set it falls back to a deterministic
  heuristic parser, so the stack always runs.
- **Shared models** — `MiseShared` is a Swift package of DTOs + filter logic compiled
  into *both* the app and the server, so the contract is a single source of truth.

## Repository layout

| Path        | What it is |
|-------------|------------|
| `Shared/`   | `MiseShared` SwiftPM package — DTOs (`Dish`, `ParsedMenu`, `DietaryTag`) and `DishFilter` logic, shared by app + server. |
| `server/`   | Vapor backend. `/health`, `POST /v1/menu/parse`, `/v1/images` (dish photos), `/v1/phrases` and `/v1/filters/interpret` (a sentence → filters). Dockerised for Railway. |
| `app/`      | SwiftUI iOS app. Xcode project is generated from `app/project.yml` via XcodeGen. |
| `railway.json` | Railway build/deploy config (Dockerfile builder, healthcheck). |
| `Makefile`  | Common build/test/run/deploy tasks — run `make help`. |

## Prerequisites

- Xcode 26+ (Swift 6.3 toolchain)
- [XcodeGen](https://github.com/yonyz/XcodeGen) — `brew install xcodegen`
- [Railway CLI](https://docs.railway.com/guides/cli) — `brew install railway` (for deploys)
- Docker (optional, to build the server image locally)

## Running locally

### Backend

```sh
# Heuristic parser (no key needed):
make server-run

# Or with LLM parsing:
ANTHROPIC_API_KEY=sk-ant-... make server-run

# Smoke test:
curl -s localhost:8080/health
curl -s localhost:8080/v1/menu/parse \
  -H 'content-type: application/json' \
  -d '{"text":"STARTERS\nTomato Soup - creamy 6.50\nVegan Bowl 12\nMAINS\nSpicy Beef Burger 14"}' | jq
```

### iOS app

```sh
make app-build          # generates the Xcode project and builds for the simulator
open app/Mise.xcodeproj # or open it in Xcode and Cmd-R
```

The app reads its backend URL from the `MiseAPIBaseURL` Info.plist key (set in
`app/project.yml`), defaulting to `http://localhost:8080` for the simulator. Point
it at your Railway URL for device builds.

> Note: `app/Mise.xcodeproj` is **generated** and git-ignored. Run `make app-gen`
> (or `xcodegen generate` in `app/`) after pulling changes to `project.yml`.

## Tests

```sh
make test          # server + app
make server-test
make app-test
cd Shared && swift test
```

## Deploying the backend to Railway

**Phone-friendly, one-tap deploy: see [DEPLOY.md](DEPLOY.md).** The project is already
created; a GitHub Actions workflow deploys on a button press.

The Dockerfile lives in `server/` but copies the sibling `Shared/` package, so the
**build context must be the repo root** — which is exactly what `railway.json`
(at the root) configures. Local CLI alternative:

```sh
railway login
railway init                 # or: railway link  (to an existing project)
railway variables set ANTHROPIC_API_KEY=sk-ant-...
railway up                   # builds server/Dockerfile, deploys, healthchecks /health
```

Railway injects `$PORT`; the server binds to it automatically (see
`server/Sources/App/configure.swift`).

## Screens (from the Menu Copilot wireframes)

Capture → Reading → Browse (filter-first) → Filters → Dish detail → My picks, plus a
smart "no matches" state that names the over-constraining filter and offers one-tap
ways to loosen it. Design tokens (terracotta `#e8743b`, cream `#fbf8f1`/`#ece7dd`,
serif dish names) live in `app/Sources/App/DesignSystem.swift`.

> Tip: launch with `-seedMenu 1` (scheme arguments or `simctl launch … -seedMenu 1`)
> to open straight into a sample menu without a backend round-trip.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full plan (now → TestFlight MVP → 1.0). Nearest up next:

- [ ] Deploy backend to Railway and point the app at it
- [ ] Dish image enrichment (populate `Dish.imageURL` server-side)
- [ ] Live camera capture (currently photo-library picker)
- [ ] App icon + signing + first TestFlight build
