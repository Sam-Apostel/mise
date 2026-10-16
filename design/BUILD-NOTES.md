# The board in SwiftUI: build notes (17 Oct 2026)

Simulator shots of the build are in [shots/build](shots/build/sheet.png), taken on an iPhone 18 Pro simulator (iOS 27.0, 402×874) from the seeds:

| Shot | Launch arguments |
|---|---|
| 01 Menu (Els) | `-seedMenu 1` |
| 02 Dish (green curry) | `-seedMenu 1 -seedScreen dish` |
| 03 Picks | `-seedMenu 1 -seedScreen picks -seedPerson everyone` |
| 04 Waiter card | `-seedMenu 1 -seedScreen waiter` |
| 05 Chalk strike frames | `-seedMenu 1 -seedPerson everyone -seedTapPerson els`, recorded |
| 06 Menu, night | `-seedMenu 1` in dark appearance |
| 07 Camera with Recent | `-seedCamera 1 -demoViewfinder` |
| 08 Icon | `app/Resources/AppIcon.icon`, rendered by Icon Composer's `ictool` |
| 09 Filters | `-seedMenu 1 -seedScreen filters` |
| 10 People (Els) | `-seedMenu 1 -seedScreen people` |
| 11 Photos still loading | `-seedMenu 3` |
| 12 Italian menu (Sam, vegetarian tonight) | `-seedMenu 2` |

## Where the build differs from the mockups

**Content and counts** (the seed follows DIRECTION.md's dish list; the mockups' counts weren't consistent with it):
- Auntie Nid's has 11 dishes including Thai iced tea, so Els reads **7 fine · 2 ask · 2 no** (the mockup says 6 fine). Luc is crossed out of more dishes, because the verdicts follow his profile (mild spice cap, dairy).
- Jay Daeng's has 6 dishes and Trattoria da Carmelo has 8, so their eyebrows and counts are smaller than the mockups' 8 and 14.
- Euro prices use today's rate (37.6 baht to the euro) and the phone's locale, so the dish screen shows "€2,93" where the mockup has "€2.95". On a real scan the rate is fetched daily from the ECB through Frankfurter.

**Layout and native behaviour:**
- The Picks, Filters and People sheets are system sheets. On iOS 26 and later they float inset from the screen edges, and nothing dims the board behind them; the mockups draw a full-width sheet over a scrim.
- With Everyone selected, Picks shows a check line for each person. The second line sits under the button fade.
- Filters starts with nothing selected (the mockup shows Pescatarian and Medium on). A "Tonight" chip only appears when at least one dish has that tag, so Pescatarian and Halal don't show on this seed, and Gluten-free does.
- "What the waiter hears" lists the languages of the menus you have actually read. This seed has only read Thai menus, so the Italian sentence doesn't appear.
- The People footer reads "At Auntie Nid's Kitchen: …" (the mockup says "On Auntie Nid's menu").
- A crossed-out drawn plate is desaturated and dimmed like a photo. The critique had asked for crossed plates to stay cream.
- The waiter card's English lines use the full dish names ("Pineapple fried rice"); the mockup shortens them.
- The camera's paper menu only appears with `-demoViewfinder`, because the simulator has no camera. On a phone the viewfinder shows the live camera, and a photo-library button sits beside the shutter.

**Signature:** the timing matches the storyboard. In the 25 fps recording (05): the chip fills at 0 ms, the line draws and the photo dims by about 240 ms, the reason fades in at about 320 to 480 ms, then the ask and no segments slide in while the count rolls 11 → 7. The light haptic fires once when the lines land. With Reduce Motion on, everything cross-fades in 200 ms and nothing re-sorts (not shot).

**Icon:** replaced at Sam's request (17 Oct) by a cream menu card with fork and knife and a mustard "A文" translate bubble on board green. It is an Icon Composer document with two layers, so the default, dark, clear and tinted renditions all work.

## Not verified
- Not run on a device: live camera capture, haptics, the brightness boost on the waiter card.
- The server's image chain hasn't been called against the live Commons, Pexels or Pixabay APIs; only the unit tests with fake providers ran. Pexels and Pixabay need `PEXELS_API_KEY` and `PIXABAY_API_KEY` on Railway.
- Dynamic Type at the accessibility sizes.
- The Railway deployment still runs the old server. Nothing has been deployed.
