# Dish image sourcing — research & decision

_Research date: 2026-06-19. Not legal advice — have counsel review the labeling/compliance
points before public launch._

The pitch promises "images of the dishes." This doc decides **how** to source them.

## TL;DR

There is **no single source that is both legally clean and highly dish-relevant** — the
sources with the best dish photos (Google Images, Places/Yelp) forbid caching/redisplay;
the ones that allow caching have weaker per-dish relevance. So use a **server-side
fallback chain**, resolve once per `dishName+cuisine`, cache the result, and never block
menu parsing on it:

1. **Spoonacular** (search by dish name) — real food photos; **its terms explicitly allow
   storing the image URL indefinitely**, which is exactly what `Dish.imageURL` needs.
   _Primary._ ($29/mo "Cook" tier; free tier is dev-only.)
2. **Pexels** (keyword search) — real food photos, commercial use + self-hosting allowed,
   no mandatory attribution. _Generic but real, free._
3. **Pixabay** (keyword search) — broad filler; **must download to our server** and cache
   responses 24h. _Free._
4. **AI generation** (Gemini Flash Image / FLUX.2 pro, ~$0.03/img) — for long-tail dishes
   the above miss. **Must be labeled "AI · illustrative."** _Last resort before placeholder._
5. **Bundled per-cuisine placeholder** — always set *something*; never a broken image.

Cache by **normalized `dishName + cuisine`** (not per-restaurant) so the same "Pad Thai"
resolves once across every menu — this is the main cost lever.

**Hard avoids:** web image-search APIs (SerpApi, Brave standard, Google CSE) and
Places/Yelp/Foursquare — their ToS forbid persistent caching/redisplay, and Google is
**actively suing SerpApi** (Dec 2025) over exactly this. Bing Image Search is **retired**
(HTTP 410, Aug 2025). Google CSE is **closing** (ends Jan 2027).

## Options evaluated

| Source | Live 2026? | Cost | Cache + redisplay allowed? | Dish relevance | Verdict |
|---|---|---|---|---|---|
| **Spoonacular** | ✅ | free dev / $29+/mo | ✅ **store image URL indefinitely** | Good (named dishes) | ✅ **Primary** |
| **Pexels** | ✅ | free | ✅ store + self-host | Generic food | ✅ Fallback 2 |
| **Pixabay** | ✅ | free | ✅ but **must self-host** + 24h response cache | Generic, broad | ✅ Fallback 3 |
| **AI generation** (Gemini/FLUX) | ✅ | ~$0.03–0.07/img once | ✅ you own output → cache to our CDN | Any dish (synthetic) | ✅ Labeled fallback 4 |
| TheMealDB | ✅ | £10 lifetime | image license undocumented ⚠️ | Weak (~300) | Maybe; get license in writing |
| Edamam | ✅ | $9+/mo, no free | per-user-password cache only; forced branding | Best breadth | ❌ poor terms |
| Unsplash | ✅ | free | ❌ hotlink-only, fire download events, no self-host | Generic | ❌ not a self-host source |
| SerpApi (Google Images) | ✅ but **Google suing** | ~$75/mo | ❌ no redisplay; 3rd-party copyright | Excellent | ❌ legal risk |
| Brave Image Search | ✅ | $5/1k | ❌ caching barred on standard plan | Good | ❌ |
| Google CSE (image) | **closing 2027** | $5/1k | ❌ transient only | Excellent | ❌ |
| Bing Image Search | **retired (410)** | — | — | — | ❌ dead |
| Google Places / Yelp / Foursquare | ✅ | $7–19/1k | ❌ **no caching** (Places), ≤24h (Yelp) | Place photos, not dish-matched | ❌ for MVP |

## AI-generation provider comparison (for fallback tier 4; ~1024², verified 2026-06)

| Provider | Recommended model | $/image | Food realism | Commercial | Caveat |
|---|---|---|---|---|---|
| **Google Gemini** | `gemini-2.5-flash-image` (Nano Banana) | **$0.039** ($0.0195 batch) | Excellent (often singled out for food) | You own output | **SynthID watermark** (a *plus* for disclosure); **Imagen EOL Aug 17 2026 — don't use** |
| **Black Forest Labs** | FLUX.2 [pro] | **$0.03** | **Best-in-class** | Commercial included (hosted API) | Open-weights license only matters if self-hosting |
| **Fal.ai** | FLUX.2 [pro] | $0.03/MP | FLUX-tier | Commercial included for pro | Avoid [dev]; low latency |
| **Replicate** | FLUX 1.1 pro / FLUX.2 | $0.04 ($0.025 dev) | FLUX-tier | License **follows the model** | Avoid FLUX **[dev]** (non-commercial) |
| **OpenAI** | GPT Image 1.5 / 2 | $0.05–0.21 high | Excellent | You own output | `gpt-image-1` **EOL Oct 23 2026** |
| **Stability** | Stable Image Ultra/Core | $0.08 / $0.03 | Good (trails FLUX) | You own output | **Enterprise license required >$1M revenue** |

If we generate: pick **Gemini Flash Image** (SynthID = free EU provenance mark) or
**FLUX.2 pro** (top realism). A few-thousand-dish AI tier ≈ **$100–500 one-time**, then
$0 from CDN.

## Licensing gotchas (the rules that shaped the chain)

- **Search-API results are leads, not assets.** SerpApi & standard Brave bar storing/
  redisplaying; underlying images are third-party copyrighted regardless. Google's Dec 2025
  suit against SerpApi is precisely about redistributing those images.
- **Google Places photos can't be cached at all** (resource names expire; must re-fetch live).
  **Yelp = 24h max** and bars AI-training use. **Foursquare** bars persistent datasets.
- **Unsplash** = hotlink + fire `download_location` event + photographer credit; no self-host.
- **Pixabay** flips it: you *must* download to your server and cache responses 24h.
- **Spoonacular**: store the image **URL** (and id/title) only — confirm whether re-hosting
  the image *binary* is allowed before proxying; delete stored data if you stop paying.
- **TheMealDB**: no published image license — get written confirmation + the £10 commercial
  key before scaling; don't ship on test key `1`.

## AI fake-food: the false-advertising constraint (applies to tier 4)

The litigation risk is **not** "using AI" — it's an image reading as *the specific dish this
restaurant serves* with details that turn out wrong (the Burger King "Whopper" / Taco Bell
false-advertising theory; survived a motion to dismiss May 2025; untested for AI but directly
analogous). AI models hallucinate plausible-but-wrong ingredients/portions — the actionable
"specific factual claim" category. **Allergen/ingredient mismatch is the worst case.** So:

1. **Label every AI image visibly and persistently** ("AI-generated · illustrative",
   "serving suggestion — actual dish may vary"). Visible label > metadata (FTC/EU judge the
   net impression; metadata gets stripped).
2. **Frame as a generic illustration**, never "here's what you'll get."
3. **Don't imply portion/exact ingredients/allergen content** in the prompt.
4. **Keep C2PA / SynthID provenance** marks — supports **EU AI Act Art. 50** (AI-content
   disclosure, applies **2 Aug 2026** for EU users).
5. **Generate server-side from dish names** (non-personal input) to avoid **Apple App Store
   Guideline 5.1.2(i)** (consent for sharing user data with third-party AI).
6. **Honor takedown/correction** so a restaurant can flag a wrong image.

(Purely AI-generated images aren't US-copyright-registrable — usable/sellable, not exclusive.)

## Recommended architecture (Vapor)

Enrichment is a one-time, cached, best-effort step, **decoupled from `/menu/parse`** so it
never adds OCR→menu latency.

```swift
func enrichImage(for dish: Dish, on req: Request) async -> ImageResult {
    let key = dish.cacheKey                       // sha256(normalize(name) | cuisine)
    if let hit = try? await ImageCache.find(key, on: req.db) { return hit }

    // First hit wins; each provider call has a 2–3s timeout and returns nil on failure.
    let result = await spoonacular(dish, req)     // real photo; store URL (ToS-OK)
        ?? await pexels(dish, req)                // real, self-host OK
        ?? await pixabay(dish, req)               // real; MUST self-host bytes
        ?? await generate(dish, req)              // AI; cache to our CDN, isAIGenerated = true
        ?? placeholder(for: dish.cuisine)         // never nil
    try? await ImageCache(key: key, result: result).save(on: req.db)
    return result
}
```

- **Cache by `normalize(name) + cuisine`**, persisted in our DB (optionally Redis-fronted),
  so identical dishes resolve once across all menus.
- **Lazy:** `/menu/parse` returns dishes with `imageURL` only for cache hits; a light
  `GET /v1/dish/image?key=…` (or a background worker) resolves misses; `AsyncImage` fills
  in on next render. Keeps parse fast and cost bounded.
- **Concurrency-limit** enrichment (N dishes at a time) to respect rate limits / Spoonacular
  points; dedupe within a menu.
- **Add `Dish.isAIGenerated`** so the iOS client renders the "AI · illustrative" label only
  on tier-4 images. (Schema change when we build this.)
- **Degrade gracefully:** the chain always terminates at the bundled per-cuisine placeholder
  (already implemented in `DishThumbnail`).

## Before-launch checklist
- [ ] Spoonacular: confirm re-hosting the image *binary* vs. URL-only; subscribe to a paid tier.
- [ ] Add `Dish.isAIGenerated` + the visible label in the app.
- [ ] If generating: choose Gemini (SynthID/cheap/compliance) vs FLUX.2 pro (max realism); add C2PA marks.
- [ ] Verify EU AI Act Art. 50 applicability for our user base; legal review of labeling + takedown path.
- [ ] Re-confirm provider prices/terms in-browser (several policy pages 403'd automated fetchers).

_Sources: Spoonacular/Pexels/Pixabay/Unsplash/Edamam/TheMealDB API terms & pricing; Google
Places, Yelp, Foursquare terms; Brave & Google CSE docs; Bing retirement notice; Google v.
SerpApi (Dec 2025); ai.google.dev pricing & Imagen-deprecation; BFL/Fal/Replicate/Stability
pricing & terms; OpenAI service terms; FTC deception policy; Harvard Law Whopper analysis;
EU AI Act Art. 50 / Code of Practice; Apple App Review Guideline 5.1.2(i)._
