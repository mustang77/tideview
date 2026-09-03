# World Cruise Academy — Affiliate Site

A single-page site of cruise-port shore-excursion guides. Use it as your
website URL for the **Viator Partner Program** (Partner ID `P00318076`) and as
the home for your affiliate links once you're approved.

## Files
- `index.html` — the whole site (self-contained, no build step, no dependencies).

## How to add your Viator affiliate links
1. In the Viator partner dashboard, use the **link builder** to search a tour
   (e.g. "Cozumel snorkeling").
2. Copy the generated link — your Partner ID `P00318076` is already baked in.
3. In `index.html`, find each `href="REPLACE_WITH_VIATOR_LINK"` and paste your
   link in place of `REPLACE_WITH_VIATOR_LINK`.
4. (Recommended) Add a SubID so you can see which port earns, e.g. append
   `&campaign=cozumel` to the link.

## How to publish it for free (GitHub Pages)
1. Merge this branch to your default branch (or push the folder there).
2. On GitHub: **Settings → Pages**.
3. Source: **Deploy from a branch** → pick the branch → folder `/root` or move
   `index.html` to `/docs` and pick `/docs`.
4. Your site goes live at `https://<username>.github.io/tideview/` (or similar).

### Even faster: Netlify Drop
Go to https://app.netlify.com/drop and drag the `world-cruise-academy` folder
in. You get a live URL in ~10 seconds — good enough to paste into the Viator
verification form.

## Important
- Keep the **affiliate disclosure** (top bar + footer). It's an FTC/legal
  requirement and Viator's terms require it too.
- Viator sells **tours & excursions**, not cruises — so the content angle here
  is "best excursions at each port," which is exactly what cruisers search for.
