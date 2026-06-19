# Deploying the backend (from your phone)

The Railway project **mise** is already created and linked. Everything is staged so the
actual deploy is a button tap. Two paths — pick one.

---

## Path A — GitHub Actions (recommended, fully staged)

A workflow ([.github/workflows/deploy.yml](.github/workflows/deploy.yml)) deploys to Railway
when you trigger it. One-time setup, then deploy is one tap.

### One-time setup (phone browser)
1. **Get a Railway token.** railway.com → project **mise** → **Settings → Tokens** →
   create a **project token** → copy it.
2. **Add it to GitHub.** github.com/Sam-Apostel/mise → **Settings → Secrets and variables →
   Actions → New repository secret** → name `RAILWAY_TOKEN`, paste the token, save.
   _(Repo settings need the mobile **browser**, not the GitHub app.)_

### Deploy (one tap, repeatable)
3. GitHub → **Actions** → **"Deploy server (Railway)"** → **Run workflow** → branch `main` →
   Run. _(Works in the GitHub mobile app or browser.)_ Watch the run for green.

### After the first successful deploy
4. **Add env vars.** railway.com → mise → the service → **Variables**:
   - `ANTHROPIC_API_KEY` = your key _(without it, the server runs the heuristic parser — still healthy)_
   - `ANTHROPIC_MODEL` = `claude-opus-4-8`
   Then re-run the workflow (step 3) so they take effect.
5. **Make it public.** Service → **Settings → Networking → Generate Domain**. Copy the URL.
6. **Tell me the domain.** I'll point the app's Release build at it and verify `/health`.

---

## Path B — Railway's native GitHub deploy (no GitHub token)

If you'd rather not manage a token: railway.com → project **mise** → **+ New → GitHub Repo**
→ authorize Railway for `Sam-Apostel/mise` → select it. Railway reads
[railway.json](railway.json) (Dockerfile builder, healthcheck) and deploys. After that it
shows a **Deploy / Redeploy** button and (optionally) auto-deploys on push to `main`. Then do
steps 4–6 above.

---

## What's already done for you
- Project **mise** created + linked on Railway.
- [railway.json](railway.json): Dockerfile builder, `/health` healthcheck, restart policy.
- [server/Dockerfile](server/Dockerfile): multi-stage Swift release build (jemalloc, static
  stdlib, non-root, binds `$PORT`).
- The server runs with **no API key** (heuristic parser), so the first deploy goes green even
  before you add `ANTHROPIC_API_KEY`.

## What I'll do once it's live
- Point the app's Release `MiseAPIBaseURL` at the Railway domain (Debug stays localhost).
- Verify `/health` and a real `/v1/menu/parse` against production (I can watch build/deploy
  logs and status via the Railway tools).
