# Mise — direction

_Design session 2026-10-17. Redesign plus rediscovery of the "Menu Copilot" app in this repo._

## Brief

**Self-authored.** Sam was asked the brief questions in the session and had not answered when design started; answers fold in when they arrive. Everything below is a working assumption until then.

1. **What it is, for whom.** Mise reads a restaurant menu you cannot read, for a table abroad. Concretely: Sam in Italy (reads some Italian, wants to know what each dish actually is and what is worth ordering), and his parents in Thailand (cannot read Thai script at all, one of them carries allergens, both want to order without a ten-minute negotiation with the waiter).
2. **Core action, first ten seconds.** Sit down, point the phone at the menu, see which dishes each person at the table can eat and what they are.
3. **Feel.** Certain, quick, at ease. References from outside apps: a good waiter who says "not that one, you'll be fine with this"; a laminated numbered Thai street-stall menu; the specials board outside a trattoria.
4. **What exists.** Name "Mise" (bundle `be.apostel.mise`), nav title "Menu Copilot", no logo, no icon, no photos. Tokens: page `#ECE7DD`, paper `#FBF8F1`, ink `#2B2B2B`, accent `#E8743B`, serif dish names. A working SwiftUI codebase with seven screens and a Vapor backend.
5. **Needs.** Screens to look at now, SwiftUI after Sam reviews. App icon (the set is empty). App Store panels later.
6. **Image generation.** No permission given, so no credits spent. Imagery in the mockups is drawn (SVG) or colour. Dish photography is also a product decision (below), not only a mockup one.
7. **Dates** (from Sam, via the parent session). Sam leaves for Sicily on 18 October 2026 and is back 27 October; his parents are in Thailand 13 November to 6 December 2026. A redesigned build before Sicily is not realistic, so Sicily is the field test (Sam photographs Italian menus for the eval set) and the real deadline is **TestFlight on the parents' phones by 10 November**, tested on real Thai menus. Sam also said to imagine unimplemented features freely.

## Current app

### Audit

Rebuilt the three screens that carry the loop into [before.html](before.html) and shot them to [shots/before](shots/before/sheet.png).

**Which face it is.** Almost exactly slop.md's "Calm Wellness": cream ground, terracotta accent, serif display, pastel chips in three hues, a dark card with a dashed viewfinder on the first screen, "Add to my picks" as an orange capsule. Competent, and indistinguishable from a wellness app.

**Scan FAILs (verbatim):**

```
before-scan     FAIL  Contrast below WCAG on solid ground: 2.41:1 15px "Snap or choose a photo…"; 3.00:1 17px "Snap a menu"
before-browse   FAIL  Contrast below WCAG: 2.44:1 17px "Scan"; "Picks"; 3.00:1 12px "Filters"; 2.80:1 15px "Starters"; "Mains"
before-browse   FAIL  Text running off the screen: "contains egg"; "contains dairy"
before-browse   FAIL  Emoji in UI copy or as icons: 🍴 🌶
before-browse   warn  Largest text is 17px. No element owns the screen.
before-browse   warn  Three saturated hue families (24°, 0°, 144°).
before-detail   FAIL  Contrast below WCAG: 2.44:1 "‹ Back"; 2.41:1 20px "Tagliatelle al Ragù"; 4.08:1 12px "popular · ordered a lot"
before-detail   FAIL  Emoji in UI copy or as icons: 🍴 🌶
```

(The "text overlapping text" FAIL on before-browse is an artefact of my rebuild, not the app.)

By eye: the first screen is a marketing sentence and a dashed rectangle; the menu screen has no hero (the restaurant name is a 17pt nav title); the chips are the loudest thing on every row and they are the least important; every thumbnail is a grey box with a fork; the verdict the user actually needs ("can I eat this?") is never stated, only implied by a row of "contains x" pills the reader has to cross-check against their own head.

### Inventory: keep / lose / unknown

**Keep** (the contract: every one of these must be in the redesign, easier to reach):

- [ ] Capture a menu (photo picker today; becomes live camera)
- [ ] Reading state (OCR, then parse) with a retake path on failure
- [ ] Dish list grouped by course, with course jump (today: course tabs)
- [ ] Dietary filters (vegetarian, vegan, gluten-free, …) with live match counts
- [ ] Avoid-allergen filters (the nine allergens in `Allergen`)
- [ ] Spice level per dish and a spice cap filter
- [ ] Price per dish with currency
- [ ] Bilingual name: translated and in the original script
- [ ] One-line "what it is" description, plus the original description
- [ ] Ingredients list
- [ ] "Popular" mark
- [ ] My picks: add from detail, list, total, remove
- [ ] Share / show-the-waiter text for the picks
- [ ] Smart empty state: names the one filter doing most damage, one-tap loosen, clear all
- [ ] Reset to scan another menu
- [ ] Seed menu for development (`-seedMenu 1`)

**Lose:**

- "Menu Copilot" as the on-screen name (decision 1 below)
- The marketing sentence and the dashed-viewfinder card on the first screen
- Ingredient like/dislike thumbs in Filters (fiddly at a table; replaced by a plain "avoid …" field and the people profiles)
- Course tabs as a second navigation row (sections with a jump menu instead)
- Emoji chilies, the fork-in-a-grey-box thumbnail, the pastel chip rainbow
- Cream/terracotta/serif look (the category default; see "The default refused")

**Unknown** (kept in the data model, surfaced only when it earns it):

- `Dish.imageURL` and the image fallback chain (decision 5)
- `Dish.confidence` (could drive the "Ask" verdict; not shown as a number)
- `kosher`, `halal`, `raw`, `healthy` tags (shown only when the menu has them)
- `maxPrice` filter (kept in the Filters sheet, not on the main screen)
- `Course.other`

### Assets harvested

Nothing beyond the code: no logo, no photos, no icon. The Thai and Italian sample content below is written for this session; the seed menu in `ScanSession.previewLoaded` (Antonio's Trattoria, four dishes) is the only existing content and is kept as the Italian sample.

## Sicily quick build (for a separate session, not done here)

A rough working build on Sam's phone before 18 October, with the current UI, so Sicily yields real Italian menu photos and parse results. Everything is already staged in the repo; this is a checklist, in order:

1. **Deploy the server.** Either path in [DEPLOY.md](../DEPLOY.md): the GitHub Actions "Deploy server (Railway)" workflow (needs a `RAILWAY_TOKEN` repo secret) or Railway's native GitHub deploy. The Railway project `mise` is already created and linked; `railway.json` builds `server/Dockerfile` from the repo root.
2. **Set variables** on the Railway service: `ANTHROPIC_API_KEY` (the Max-plan API budget) and `ANTHROPIC_MODEL`. Without the key the server runs the heuristic parser, which is useless for Italian menus; with it, `/v1/menu/parse` returns translated dishes.
3. **Generate a public domain** (Service → Settings → Networking) and check `GET /health` and one `POST /v1/menu/parse` with a real menu text.
4. **Point the app at it.** `MiseAPIBaseURL` in `app/project.yml`: Release → the Railway domain, Debug stays `http://localhost:8080`. Regenerate the project (`make app-gen`).
5. **Sign and install.** Set `DEVELOPMENT_TEAM` in `app/project.yml`, register `be.apostel.mise` (automatic signing does this on first build), build to the phone from Xcode with a development profile. No TestFlight needed for Sam's own phone; a 7-day free-profile install is enough for a 9-day trip only with a paid team, which Sam has (hub task mentions copying Voetencomputer's fastlane).
6. **Add the camera usage string** (`NSCameraUsageDescription`) and photo-library string if the picker is kept; the picker is the only capture path today and works for a field test.
7. **Log every scan** server-side (menu text in, parsed JSON out) so Sicily produces the eval set the hub task "Parse-quality eval set" asks for. Never log images (the app sends text only).

Risks: OCR of Italian menus on-device is fine; roaming failures leave the app on the error state, so retake and retry must at least work. Cost guard: a per-device key or a simple rate limit before the URL leaves Sam's phone.

## Rediscovery

### What Mise is

A menu reader for a table abroad. Not a "copilot", not a food guide: it answers three questions at the table, in this order, for each person sitting there:

1. **Can I eat this?** Fine / ask / no, per person, from their profile.
2. **What is it?** One plain sentence, and the name in both scripts.
3. **How do I order it?** The words, in the local script, including the allergy sentence.

### Unbuilt features, weighed

| Candidate | In the core loop? | Why |
|---|---|---|
| Live camera instead of photo library | **Yes, it is the first screen** | The ten-second action starts with pointing. A picker adds two taps and a trip to Photos. |
| Thai and Italian script; photo straight to a vision model | **Yes (backend decision)** | Vision OCR is excellent on Latin menus; on a Thai menu shot at an angle under a stall lamp it is not. For non-Latin scripts send the photo to the model. The UI is the same either way: the user never sees OCR text, only the photo being read and then the dishes. Raised as hub task "Decide: Thai-script OCR on-device or photo to the model". |
| Per-person allergen profiles | **Yes, it replaces Filters as the primary control** | The parents share one phone and have different constraints. "Who is eating" is the question; dietary filters are the implementation. Filters stay, one level down, for the mood of the day (vegetarian tonight, nothing above mild, under €15). |
| "Order this" phrase card in the local language | **Yes, it is what Picks produces** | The picks list exists; its output today is a plain-text share. The redesign makes it a card you turn to the waiter: dish names in the local script, quantities, and the allergy sentence ("ฉันแพ้ถั่วลิสง" / "Sono allergica alle arachidi"). |
| Offline cache of a scanned menu | **Yes, quietly** | Roaming dies between the scan and dessert. Menus persist; the camera screen lists the last few ("Last night · Auntie Nid's Kitchen"). Already a hub task (SwiftData). |
| Price conversion | **Yes, small** | "฿120 · €3.20" on every price, and both totals on the picks. Rate fetched once a day, stale rate marked. |
| Dish images with the decided fallback chain | **Yes, the row's hero** | Sam's call: when the translated name means nothing to you, the photo is the answer to "what is it". The chain returns *a* Pad Thai, not this stall's, and the UI says so once ("photos are typical, not this kitchen's"). Zero-hit menus fall back to the drawn plate, so the layout never breaks. |
| An "Ask" verdict (new) | **Yes** | Menus omit shrimp paste, fish sauce and peanut garnish. A confident "fine" would be a lie; a blanket "no" makes the app useless. "Usually contains shrimp paste, ask" plus the question in Thai is what a good waiter friend would say. |
| Sort by "fine first" (new) | **Yes** | Unsafe dishes are crossed out and stay visible (hidden reads as "missing"), fine dishes rise. A toggle hides the crossed-out ones. |

### The core loop, redesigned

Camera (first screen, also home) → Reading → **Menu** (the hero screen: people row, dishes with verdicts) → Dish → Picks → **Waiter card**. People and Filters are sheets over Menu. No tab bar: the app is one flow, and the thumb zone on every screen holds the one next action.

## Decisions for Sam

Changes that alter the product. None of these is made silently; the mockups show the recommended option. **Updated 17 Oct after Sam's review:** the look is now A+C (the board), and decision 5 is reversed (photos in the loop).

1. **Name.** "Mise" on screen everywhere; "Menu Copilot" goes. App Store subtitle "Reads the menu for your table". (Alternative: keep both; I would not.)
2. **Structure.** No tab bar. One flow with sheets (People, Filters, Picks). The current app also has no tab bar, so this is a confirmation, but the roadmap's "Recent scans" and "Settings" would normally argue for tabs; here they live on the camera screen (recents) and a gear sheet.
3. **Hero screen.** The read Menu with per-person verdicts, as a two-column grid of numbered dish photos, not a text list. The camera is first but is a doorway.
4. **Crossed out, not hidden.** Dishes a person cannot eat stay in the list with a strike and the reason. Hiding is a toggle.
5. **Dish images in the core loop** (Sam, 17 Oct: a translated name alone does not tell you what the dish is). The chain that ships in the TestFlight build costs $0 a month (Sam, 17 Oct): Wikimedia Commons, then Pexels, then Pixabay, then the drawn plate. AI image generation is off. This replaces the June research's Spoonacular-first chain in `docs/research/dish-images.md`. The design treats the photo as the row's hero and the drawn plate as the last tier, so a menu with zero photo hits still looks finished.
6. **Dropped:** ingredient thumbs up/down; course tabs (replaced by section headers and a jump menu); the capture-screen copy.
7. **Added:** people profiles; the Ask verdict; the waiter card with the allergy sentence; currency conversion; recent menus on the camera screen.
8. **Backend:** photo to the vision model for non-Latin scripts (Thai first). On-device OCR stays for Latin scripts.
9. **Order by number** (new with the board). Every dish shows the menu's own number in a painted chip with its price; the waiter card leads each line with the number, because pointing at "07" works in any language.
10. **Images cost nothing** (Sam, 17 Oct). The chain is all free services; nothing is billed per month or per image. The only running cost is menu parsing on the Anthropic API, a few cents a scan, inside the $100/month budget.
    - **Wikimedia Commons** first: free API, good coverage of named Thai and Italian dishes. Many photos are CC BY or CC BY-SA, so the dish screen shows a one-line credit ("Photo: name, CC BY-SA") under the photo. Search by the dish's original name, then the English one.
    - **Pexels**, then **Pixabay**: free stock libraries for what Commons misses. Both allow caching and re-hosting; Pixabay requires it.
    - **The drawn plate** when all three miss.
    - Results are cached on the server by dish name and cuisine, so each dish is looked up once across every menu.
    - **AI generation stays off.** If it ever comes back, it is a per-dish button with a hard monthly cap set on the server, never automatic.

## The default refused

**The category.** Google Translate's camera, the menu-translation apps on the Store, and Yelp/TheFork share: a white screen, a blue or red brand button, a photo-overlay translation, and food photography as decoration. The menu apps that try to look "restaurant" reach for cream paper, terracotta, a serif, and a chalkboard texture image. The current Mise is that paper-and-terracotta app.

**Refused:** cream ground, terracotta accent, serif-for-elegance, pastel chip rainbow, food photography *as decoration* (photos are content here: one per dish, framed as a numbered set, never a hero banner of a lifestyle table), grey placeholder thumbnails, a blue translate button, any texture image. Also refused: this skill's own grey-paper-mono-red ticket.

**The colour cliché.** Thai flag red-white-blue and Italian green-white-red are both out; so is "appetite orange".

## Exploration

Three concepts, each from a different source family, rendered on the real core screen (the read Thai menu, Els selected) in [explore.html](explore.html), shot to [shots/explore](shots/explore/sheet.png).

**A. "Mise is the specials board outside the trattoria."** (object) Dark slate ground, chalk ink, condensed capitals, teal chalk for selection, one red chalk line through what you cannot eat. Richness: colour and material (chalk on slate, drawn with colour and rule, never a texture) plus chalk-line drawings of ingredients. Signature: the strike.

**B. "Mise is a plate on a white tablecloth."** (object) Light cool-bone ground, SF Rounded Heavy names, every dish a top-down plate drawn flat in one hand, a red ring and cross for what you cannot eat. Richness: illustration. The drawn plate doubles as the image fallback the product needs.

**C. "Mise is the numbered laminated menu at a Bangkok stall."** (place) Saturated colour fields that mean the verdict (green: fine, mustard: ask, red: no), cream ink, Bricolage Grotesque numerals as the shape language, order-by-number. Richness: colour field and shape.

Axes: grounds dark / light / colour-field; type condensed / rounded / custom display; accent teal / red / green; richness colour-material / illustration / shape.


### The choice, revised: A and C merged

First pick was B (the plate); Sam reviewed the sheet and chose **A and C, read as the dark and light faces of one style**, and asked for dish photos to carry the "what is it" job. Shot: [shots/explore/sheet.png](shots/explore/sheet.png).

What A and C share, and what the merged direction keeps: a bold condensed display face in capitals; a saturated ground that does the work (slate in the dark, painted-sign green in daylight); the verdict as structure (A's strike through what you cannot eat, C's three verdict colours); order-by-number.

- **From A:** the slate ground for dark mode, the red strike through a crossed-out dish, the chalk-cream ink, the course sections.
- **From C:** the green field for light mode, Bricolage Grotesque, the menu numbers, the three verdict colours (green fine, mustard ask, red no) now used as a summary bar and as row marks, not as whole-screen grounds (the "Everyone" state has no verdict, so a ground that means verdict breaks).
- **Dropped from B:** the drawn plate as the richness source. It survives as the last tier of the image chain and as the icon.
- **B lost** on Sam's taste: too soft, and a drawing cannot answer "what is it" the way a photo does.

**History check:** the merged direction is `place / colour-field / condensed / red / photo`. Against Reizo (`nature / colour-field / serif / orange / colour-material`) it differs on 4 of 5; against Reizo v2 (`place / image / expanded / yellow / photo`) on 3 of 5 (ground, type, hue); against the current Mise look on 5 of 5. The earlier Mise row in the history file is replaced by this one.

## Direction

**Mise is the painted menu board outside a Thai stall: numbered photos, a verdict chalked on each.** Daylight: a painted-sign green board with cream lettering. Night: the same board as slate and chalk. Every dish is a numbered photo tile; what you cannot eat gets a red chalk line through it.

### Tokens

| Role | Light ("board, daylight") | Dark ("board, night") | Note |
|---|---|---|---|
| ground | `#176A47` | `#15201A` | the board: painted green by day, green-black slate by night; the hue survives |
| raised | `#F8F1E0` | `#F8F1E0` | the cream card (waiter card, sheets); cream in both modes, like paper on the board |
| tile | `rgba(248,241,224,.10)` | `rgba(248,241,224,.08)` | photo tile frame fill; the photo sits inside a 1px cream hairline |
| ink | `#F8F1E0` | `#F1ECE0` | cream, chalk |
| ink-2 | `rgba(248,241,224,.74)` | `rgba(241,236,224,.72)` | 6.9:1 on light ground |
| ink-3 | `rgba(248,241,224,.58)` | `rgba(241,236,224,.56)` | ≥4.5:1 |
| rule | `rgba(248,241,224,.2)` | `rgba(241,236,224,.16)` | |
| on-raised ink | `#1B211E` | `#1B211E` | text on cream |
| no (accent) | `#F0836F` | `#F0836F` | **one role: "not for you."** The strike, the reason line, the allergy block on cream uses its deep value `#B8321F`. |
| ask | `#E8B84A` | `#E8B84A` | the second semantic colour the domain needs: "ask first". Only the ? mark and the ask line. |
| fine | the ground itself | the ground itself | a fine dish gets no mark; green is the board |
| selection | cream on ground, ground on cream | same | people chips and segmented controls: filled cream, text in ground colour |

Hue families on a screen: green (ground), red, mustard. Photos are content.

**Type.** Two families. **Bricolage Grotesque** (OFL, variable: wght 200–800, wdth 75–100, opsz 12–96; bundle it and map to Dynamic Type) at **width 80, weight 800, uppercase** for display: restaurant name, dish names, menu numbers, the waiter card. `SF Pro` for everything else. Thai and Italian script set in SF Pro (system fallback), one step below the English, in ink-2.

| Step | Size / leading | Face | Tracking | Used for |
|---|---|---|---|---|
| display | 44 / 44 | Bricolage 800, wdth 80, caps | -0.5 | restaurant name; waiter-card dish lines (Thai in system face) |
| number | 34 / 34 | Bricolage 800, wdth 80 | -1 | menu number on a tile; the summary bar counts |
| name | 20 / 22 | Bricolage 800, wdth 80, caps | 0 | dish names on tiles and rows |
| body | 17 / 22 | SF 400 / 600 | -0.4 | descriptions, buttons |
| secondary | 15 / 20 | SF 400 / 600 | -0.2 | original script, prices, summary |
| meta | 13 / 17 | SF 400 / 600 | +0.2 | eyebrows, reasons, captions; section labels in Bricolage 700 caps +1 |

Six steps. Prices tabular (SF).

**Layout.** Side margin 20. Tiles in a 2-column grid, gutter 12, photo 4:3 inside a 1px cream hairline, radius 10; numbers chip on the photo's bottom-left. Radius family: 10 (tiles, fields), capsule (buttons, chips), 26 (cream card and sheets). Spacing 4, 8, 12, 16, 24, 32, 48.

### The richness source: the numbered photo

An art direction for photos the app does not take: the chain returns mismatched photos (overhead stall shots, restaurant plates, a stock bowl), so the design makes them read as one set by framing: every photo is cropped 4:3, sits inside the same cream hairline on the same green, carries the same number chip, and is slightly warmed and lifted in contrast on display (one `CIColorControls` pass, +0.05 saturation, +0.1 contrast). Commons photos that need attribution carry a one-line credit on the dish screen, never on the grid. Missing photos show the drawn plate archetype (from the B exploration, kept as the last tier) on the tile ground.

In the mockup the photos are Wikimedia Commons stand-ins, credited in [img/CREDITS.md](img/CREDITS.md); they are not the product's images and must not ship.

### The signature: the chalk strike

Trigger: tap a person in the people row.

1. **0 ms.** The chip fills cream; selection haptic.
2. **0 to 260 ms.** On every tile that person cannot have, a red chalk line draws from the photo's top-left to bottom-right (a slightly wobbly path, `trim` 0 to 1, `.smooth`), and the photo desaturates to 30% and dims.
3. **260 ms.** Light impact haptic as the line lands, once for the whole screen.
4. **260 to 400 ms.** The reason line ("Peanuts, dried shrimp") fades in under the name in red; "ask" tiles get the mustard ? at the same moment.
5. **300 to 700 ms.** Crossed tiles sink to the end of their course (`.spring(duration: 0.4, bounce: 0)`); the summary bar's three segments re-proportion and the counts roll.

Switching person erases the old lines back along their path while the new ones draw. Reduced motion: lines cross-fade in 200 ms, no reorder animation, haptics stay.

## Content

The Thai menu is written for this session (Auntie Nid's Kitchen is invented; dishes and prices are typical Bangkok stall prices, rate ฿37.6 per euro). The people are invented stand-ins for Sam's parents: **Els** (avoids peanuts and shellfish) and **Luc** (nothing above mild, avoids dairy). Sam's own phone would show the Italian seed menu with one profile.

### Camera (first screen, also the empty state)
- Viewfinder full-bleed. Through it, a paper menu, hand-held, slightly rotated, with the lines the app has found underlined as they are read.
- Top left: a glass circle, gear. Top right: a glass capsule "Who's eating · 2".
- Over the viewfinder bottom: "Hold still, reading the menu" then "9 dishes so far".
- Under the viewfinder: "Recent" with two rows: "Auntie Nid's Kitchen · Thai · last night", "Jok Prince · Thai · Tue". Tap to reopen without a connection.
- First run, before any profile exists: the capsule reads "Add who's eating" and the summary on Menu reads "For everyone: 11 dishes. Add a person to see what they can eat."

### Menu (core screen, mid-use)
- Toolbar: left glass circle camera (scan another), right glass capsule "Picks · 2".
- Below the people row, a three-segment summary bar: green 6 fine · mustard 2 ask · red 3 no, tappable to show only that group.
- Dishes as numbered photo tiles in two columns, in menu order, crossed-out tiles sinking to the end of their course. A tile: photo, number chip, name (Bricolage caps), Thai name, price in ฿ and €; the one-line "what it is" moves to the dish screen because the photo answers it on the grid.
- Eyebrow: "ครัวป้านิด · Thai · 11 dishes". Title: "Auntie Nid's Kitchen".
- People row: Everyone (∞) · **Els** (selected) · Luc · Add (+).
- Summary: "For Els: **6 fine**, 2 to ask about, 3 she can't have."
- Course "Salads and soups": Tom Kha Gai ต้มข่าไก่, "Coconut and galangal soup with chicken. Mild." ฿95 · €2.55 — Som Tam Thai ส้มตำไทย, crossed: "Peanuts, dried shrimp" ฿70 · €1.90.
- Course "Mains": Pineapple fried rice ข้าวผัดสับปะรด "Fried rice with pineapple, egg, raisins and cashews, served in the pineapple." ฿130 · €3.45 — Hat Yai fried chicken ไก่ทอดหาดใหญ่ "Southern fried chicken with crispy shallots." ฿90 · €2.40 — Green curry, chicken แกงเขียวหวานไก่, ask: "Usually has shrimp paste. Ask." ฿110 · €2.95 — Morning glory, stir-fried ผัดผักบุ้งไฟแดง, ask: "Oyster sauce is likely. Ask." ฿60 · €1.60 — Pad Thai, prawns ผัดไทยกุ้งสด, crossed: "Peanuts, prawns" ฿120 · €3.20 — Steamed sea bass, lime ปลากะพงนึ่งมะนาว ฿280 · €7.45.
- Course "Sweet": Mango sticky rice ข้าวเหนียวมะม่วง ฿85 · €2.25. Course "Drinks": Fresh coconut น้ำมะพร้าว ฿40 · €1.05; Thai iced tea ชาเย็น ฿45 · €1.20 (dairy).
- Thumb zone: ink capsule "Filters", glass circle microphone (say a dish name, or ask "which of these is a soup").

### Dish: Green curry, chicken
- Hero: the dish photo full-bleed to 330pt with the painted chip "05 · ฿110" on its bottom-left; directly under it "Typical photo, not this kitchen's." Then "Green curry, chicken", "แกงเขียวหวานไก่", "฿110 · €2.95".
- "For the table": Els, "Usually has shrimp paste. Ask." (mustard, with the question in Thai: "มีกะปิไหม"); Luc, "Not for Luc: hot, he keeps to mild." (red, with three chilis on this menu's scale).
- "Contains" comes before "What it is", because ingredients are the allergy check.
- "What it is": "Coconut-milk curry with green chili paste, Thai basil, pea aubergine and bamboo shoot. One of the hotter curries on a Thai menu."
- "In the original": "แกงเขียวหวานไก่ เสิร์ฟพร้อมข้าวสวย" (served with steamed rice).
- "Contains": chicken, coconut milk, green chili, Thai basil, pea aubergine, bamboo, fish sauce; "Probably: shrimp paste".
- Thumb zone: cream capsule "Add to picks", outline "Ask the waiter" (opens the phrase card with มีกะปิไหม).

### Picks (sheet over Menu)
- Title "Picks · for the table". Rows: 1 × Tom Kha Gai ฿95; 2 × Pineapple fried rice ฿260; 1 × Hat Yai fried chicken ฿90; 1 × Fresh coconut ฿40.
- Total ฿485 · €12.90. Button: "Show the waiter".

### Waiter card (full screen, the output)
- Cream card on the board, rounded 26: big Thai text, each line led by the menu number, English small under each line.
- "Order for Els · ขอสั่ง" with Els's initial, then: "ต้มข่าไก่ ×1", "ข้าวผัดสับปะรด ×2", "ไก่ทอดหาดใหญ่ ×1", "น้ำมะพร้าว ×1".
- Then in red, the allergy line: "แพ้ถั่วลิสง กุ้ง และปู / ไม่ใส่ถั่ว กุ้ง ปู" (allergic to peanuts, shrimp and crab: none of them, please). The profile's "Shellfish" chip names shrimp and crab so the chip, the Thai and the Italian say the same thing.
- "ขอบคุณค่ะ" thank you. Bottom: small "Tap to flip to English", brightness goes to max while shown.

### Signature storyboard (four frames)
Frame 1: Everyone selected, all photos clean. Frame 2: Els tapped, the chalk line half-drawn across Som Tam and Pad Thai. Frame 3: the line has landed, photos desaturated, reasons visible, mustard ? on the ask tiles. Frame 4: crossed tiles settled at the end of their course, the summary bar reads 6 fine · 2 ask · 2 no.

### Menu, dark
Same as Menu on the night board (#182B21), photos at 88% brightness, at 21:15.

### Filters (sheet over Menu, Els selected)
Filters are the mood of the meal, on top of each person's fixed profile. Cream sheet, grabber, title "Filters", trailing "Clear".
- "Tonight": Vegetarian 3 · Vegan 1 · Pescatarian 4 · Halal 6 (chips with live counts; Pescatarian selected).
- "Spice, up to": Any · Mild · Medium · Hot (segmented, with 0 to 3 amber chilis; Medium selected).
- "Price, up to": ฿150 · €4.00 on a slider; "8 dishes under".
- "Courses": Salads and soups · Mains · Sweet · Drinks (all on).
- "Also avoid": a field with one chip "coriander ×" and the hint "Add an ingredient".
- Toggle "Hide what's crossed out" (off): crossed dishes stay visible, struck.
- Button (ground green, cream text): "Show 6 dishes".

### People (sheet: editing Els)
- Header: Els's initial in a cream circle, name field "Els", trailing "Done".
- "Allergic to" (red when selected): Peanuts ✓, Shellfish ✓, Tree nuts, Sesame, Gluten, Dairy, Egg, Fish, Soy. Under it a toggle "Severe: put it on the waiter card" (on).
- "Avoids" (not allergic, just doesn't eat): Pork.
- "Spice, up to": Hot (three chilis).
- "The sentence for the waiter", previewed in the languages of recent menus: Thai "แพ้ถั่วลิสง กุ้ง และปู ไม่ใส่ถั่ว กุ้ง ปู"; Italian "Sono allergica alle arachidi e ai crostacei: gamberi, granchio."; English under each.
- Footer line: "On Auntie Nid's menu: 6 fine, 2 ask, 2 no."

### Photos still loading (the zero-photo state)
A new stall on a weak signal: the parse came back, the image lookups did not. Every tile shows its drawn plate archetype on the tile ground, with the same chip; verdicts are complete.
- Eyebrow "ร้านเจ๊แดง · Thai · 8 dishes", title "Jay Daeng's".
- A cream strip under the summary: "Weak signal. Photos will fill in; the verdicts are ready."
- Tiles: 01 Khao man gai ข้าวมันไก่ ฿60; 02 Kuay teow nam ก๋วยเตี๋ยวน้ำ ฿55; 03 Pad kra pao, pork ผัดกะเพราหมู ฿65 (crossed for Els: "Pork"); 04 Tom yum goong ต้มยำกุ้ง ฿120 (crossed: "Shrimp"); 05 Khao pad ข้าวผัด ฿60; 06 Cha yen ชาเย็น ฿35.

### Italian menu (Sam alone, Ortigia)
Sam in Sicily, one profile, a "vegetarian tonight" filter on. Names that are the dish's proper name stay in Italian as the title, with a short English gloss under (the parser's `originalName` and `name`), two or three words so it fits one line on a tile; the full description lives on the dish screen. Prices in € only, the home currency.
- Eyebrow "Ortigia, Siracusa · Italian · 14 dishes", title "Trattoria da Carmelo".
- People: Sam (selected) · +. Under it an active filter chip "Vegetarian ×".
- Summary: "7 fine tonight · 1 ask · 3 not vegetarian".
- Antipasti: 02 Caponata, "Sweet-sour aubergine stew", €8 · 01 Arancino al ragù, crossed "Meat ragù", €3.50.
- Primi: 05 Pasta alla Norma, "Tomato, fried aubergine, salted ricotta", €12, popular · 06 Tagliatelle al ragù, crossed "Beef and pork", €14.
- Secondi: 09 Parmigiana di melanzane, "Aubergine baked with tomato and cheese", €11, ask "Parmigiano uses animal rennet. Ask." · 11 Involtini di pesce spada, crossed "Fish", €18, no photo found (drawn plate).
- Dolci: 14 Cannoli, "Ricotta, pistachio", €5 · 15 Tiramisù, "Coffee, mascarpone", €6.

### Not designed this round
Settings, the reading-failed state, the first-run state before any profile exists, a dark version of each sheet. All follow the tokens above. The B-plate direction's screens are archived in `mockup-b-plate.html` and `shots/b-*`.
