# Dish image sourcing — research & decision

_Research date: 2026-06-19. Not legal advice — have counsel review the labeling/compliance
points before public launch._

The pitch promises "images of the dishes." This doc decides **how** to source them.

## TL;DR

**Generate dish images with an AI text-to-image model, server-side, from the dish
name + cuisine — then review/cache once and serve from our own CDN.** Frame them as
generic *illustrations* (not "the exact plate this restaurant serves") with a visible
"AI · illustrative" label. This is the cheapest, highest-coverage, and most
legally-defensible path.

- **Primary provider:** Google **Gemini Flash Image** ("Nano Banana", `gemini-2.5-flash-image`,
  ~$0.039/image) — strong on food, commercial rights included, and its built-in
  **SynthID watermark doubles as the EU AI Act provenance mark**. Close alternative:
  **FLUX.2 [pro]** via **Black Forest Labs** or **Fal.ai** (~$0.03/image, best-in-class
  food realism).
- **Avoid:** web image-search APIs (copyright + ToS forbid caching/redisplay), FLUX
  **[dev]** variants (non-commercial), **Stability** above $1M revenue (enterprise
  license required), and the sunset models `gpt-image-1` (EOL Oct 2026) / Google
  **Imagen** (EOL Aug 2026).

## Options evaluated

| Approach | Coverage of arbitrary dishes | Cost | Legal/ToS | Verdict |
|---|---|---|---|---|
| **Web image search** (Google CSE, SerpAPI, Brave; Bing retired) | High | Low–med (per query) | ❌ Results are third-party copyrighted; most APIs' ToS **forbid caching/redisplaying** images. Provenance unknowable. | **Reject** — infringement risk |
| **Stock photo APIs** (Unsplash, Pexels, Pixabay) | Low (generic, not the dish) | Free–low | ✅ Permissive, attribution varies | Weak — rarely matches the actual dish |
| **Recipe/meal DBs** (TheMealDB, Spoonacular, Edamam) | Low–med (common dishes only) | Free–med | ✅ usually licensed for app use (verify) | Useful **supplement** for popular dishes; poor long-tail coverage |
| **Place/review photos** (Google Places, Yelp, Foursquare) | Med (restaurant-specific) | Med, strict ToS | ⚠️ Display rules + attribution; tied to a matched venue | Future enhancement once we resolve the restaurant |
| **AI generation** (FLUX, Gemini, OpenAI) | **High (any dish)** | ~$0.03–0.07/image once, then $0 from CDN | ✅ You own/commercially use output (per-provider, see below) | ✅ **Chosen** |

### Why AI generation wins for MVP
Coverage is the deciding factor: a scanned menu has arbitrary, long-tail dishes that
stock/recipe/search sources won't reliably have. Generation always produces *something*
relevant, at a uniform style, for a few cents amortized to ~$0 via caching.

## AI-generation provider comparison (~1024², verified 2026-06)

| Provider | Recommended model | $/image | Food realism | Commercial | Caveat |
|---|---|---|---|---|---|
| **Google Gemini** | `gemini-2.5-flash-image` (Nano Banana) | **$0.039** ($0.0195 batch) | Excellent (often singled out for food) | You own output | **SynthID watermark on every image** (a *plus* for disclosure); **Imagen is EOL Aug 17 2026 — don't use it** |
| **Black Forest Labs** | FLUX.2 [pro] | **$0.03** | **Best-in-class** | Commercial included (hosted API) | Open-weights license only matters if self-hosting |
| **Fal.ai** | FLUX.2 [pro] | $0.03/MP | FLUX-tier | Commercial included for pro | Avoid [dev]; low latency |
| **Replicate** | FLUX 1.1 pro / FLUX.2 | $0.04 ($0.025 dev) | FLUX-tier | License **follows the model** | Avoid FLUX **[dev]** (non-commercial) |
| **OpenAI** | GPT Image 1.5 / 2 | $0.05–0.21 high; ~$0.005–0.02 low | Excellent | You own output | `gpt-image-1` **EOL Oct 23 2026** — target successors |
| **Stability** | Stable Image Ultra/Core | $0.08 / $0.03 | Good (trails FLUX) | You own output | **Enterprise license required >$1M revenue** |

**Pick:** Gemini Flash Image (SynthID = free provenance for EU compliance) or FLUX.2 pro
(top realism). Both ~$0.03–0.04, both clean commercial terms. A few-thousand-dish
catalog ≈ **$100–500 one-time**.

## Legal & compliance (the part that actually constrains the design)

The litigation risk is **not** "using AI" — it's an image reading as *the specific dish
this restaurant serves* with details that turn out wrong (the Burger King "Whopper" /
Taco Bell false-advertising theory; survived a motion to dismiss May 2025; untested for
AI but directly analogous). AI models hallucinate plausible-but-wrong ingredients/portions,
which is exactly the actionable "specific factual claim" category. **Allergen/ingredient
mismatches are the worst case.**

Design rules that follow:
1. **Label every AI image visibly and persistently** — e.g. "AI-generated · illustrative"
   plus "serving suggestion — actual dish may vary." Visible label > metadata (the FTC and
   EU judge the *net impression*, and metadata gets stripped in transit).
2. **Frame as a generic illustration**, not the vendor's actual plate. Copy: "Example of
   [dish type]," never "Here's what you'll get."
3. **Don't let the image imply portion size, exact ingredients, sides, or anything
   allergen-relevant.** Keep prompts stylized/representative.
4. **Embed C2PA Content Credentials** (and rely on Gemini's SynthID) as the machine-readable
   mark — helps with **EU AI Act Art. 50**, which applies **2 Aug 2026** for AI-content
   disclosure if we have EU users. Pair with the visible label, don't rely on it alone.
5. **Generate server-side from non-personal inputs** (dish names) so we don't trigger
   **Apple App Store Guideline 5.1.2(i)** (consent for sharing user data with third-party AI).
6. **Honor takedown/correction** so a restaurant can flag a wrong image.

(US copyrightability note: purely AI-generated images aren't copyright-registrable in the
US — we can use/sell them but can't claim exclusive copyright. Fine for this use.)

## Recommended architecture (Vapor)

A server-side enrichment step, decoupled from the parse response so it never blocks OCR→menu:

```
parse menu ──> for each dish: imageKey = sha256(normalize(name) | cuisine | styleVersion)
                              │
                   ┌──────────┴───────────┐
              cache HIT                cache MISS
                   │                        │
          return CDN URL          enqueue generation job
                                  (Gemini/FLUX) ──> moderate/accept
                                  ──> store on object storage/CDN
                                  ──> next load picks it up
```

- **Lazy + cached:** `/menu/parse` returns dishes with `imageURL` set only for cache hits;
  the app shows the existing placeholder otherwise. A lightweight `GET /v1/dish/image?key=…`
  (or a background worker) generates-and-caches on demand; `AsyncImage` fills it in on the
  next render. Keeps parse latency low and cost bounded.
- **Cache key** = `sha256(normalizedName | cuisine | styleVersion)` so identical dishes
  across menus reuse one image, and bumping `styleVersion` lets us bulk-regenerate.
- **Storage:** Railway volume or an S3/R2 bucket fronted by a CDN; serve immutable URLs.
- **Prompt template** (stylized, generic): _"A single appetizing studio photo of {dish},
  {cuisine} cuisine, on a plain neutral background, soft natural light, no text — a generic
  illustration, not a specific restaurant's plating."_
- **Degrade gracefully:** generation failure/timeout → keep the SF Symbol placeholder
  (already implemented in `DishThumbnail`).
- **Cost control:** cache aggressively, cap generations per request, prefer the cheap tier.

## Before-launch checklist
- [ ] Confirm provider terms in-browser (some policy pages 403'd to automated fetchers).
- [ ] Decide Gemini (SynthID/cheap/compliance) vs FLUX.2 pro (max realism).
- [ ] Add the visible "AI · illustrative" label + C2PA marks.
- [ ] Verify EU AI Act Art. 50 applicability for our user base.
- [ ] Legal review of labeling + a takedown path.

_Sources captured during research: BFL/Fal/Replicate/Stability pricing & terms pages,
ai.google.dev pricing & Imagen-deprecation docs, OpenAI service terms, FTC deception
policy, Harvard Law analysis of the Whopper case, EU AI Act Art. 50 / Code of Practice,
Apple App Review Guidelines 5.1.2(i)._
