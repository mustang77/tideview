# World Cruise Academy — Affiliate Site

A single-page site of cruise-port shore-excursion guides. Use it as your
website URL for the **Viator Partner Program** (Partner ID `P00318076`) and as
the home for your affiliate links once you're approved.

## Files
- `index.html` — the whole site (self-contained, no build step, no dependencies).

## What's on the page
- 12 port guides (Caribbean, Mediterranean, Alaska, Pacific & Mexico) with a
  region filter, scenic art per region, and a written mini-guide for each port.
- Hero, "Why book ahead", "How it works", About, and FTC disclosure.

## How to add your Viator affiliate links
The 12 ports live in a `PORTS = [ ... ]` array inside the `<script>` block near
the bottom of `index.html`. Each entry has a `link:` field set to
`"REPLACE_WITH_VIATOR_LINK"`.

1. In the Viator partner dashboard, use the **link builder** to search a tour
   (e.g. "Cozumel snorkeling").
2. Copy the generated link — your Partner ID `P00318076` is already baked in.
3. In `index.html`, replace each `REPLACE_WITH_VIATOR_LINK` with the matching
   port's real link.
4. (Recommended) Add a SubID so you can see which port earns, e.g. append
   `&campaign=cozumel` to the link.

## Other affiliate link placeholders (extra income)
Besides the 12 port links, the site has three more revenue slots:
- `REPLACE_WITH_INSURANCE_LINK` — cruise travel insurance (e.g. SafetyWing,
  World Nomads, Allianz partner link).
- `REPLACE_WITH_TRANSFER_LINK` — airport/port transfers (Viator sells these too;
  generate a transfer link in your Viator dashboard).
Replace them the same way as the port links.

## Newsletter signup
The email box uses a graceful fallback: until you connect a provider it just
shows a thank-you message. To actually collect emails, set the form's `action`
in `index.html` (search for `id="newsForm"`):
- **Formspree** (fastest): `action="https://formspree.io/f/XXXX"`
- **Mailchimp / MailerLite / ConvertKit**: paste your embedded form's action URL
  and make sure the email input's `name` matches what your provider expects.

## Add / edit ports
Edit the `PORTS` array — copy an entry, change `region`, `name`, `guide`, and
`tours`. Use one of the existing region names so it picks up the scenic art and
the filter: `Caribbean`, `Mediterranean`, `Alaska`, or `Pacific & Mexico`.

## Want real photos instead of the SVG art?
Each card's `<div class="scene">` renders region art. To use a photo, replace
that scene block with `<img src="your-photo.jpg" alt="Port name">` and upload
the image alongside `index.html`.

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
