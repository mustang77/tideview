# WordPress Site

A WordPress site with two custom themes and a Docker setup for local development:

- **World Cruise Academy** (`wp-content/themes/world-cruise-academy`) — landing
  page + news blog for a cruise ship training school. Light professional design
  (navy/gold) with hero, training programs, why-us, stats band, and enroll CTA.
- **TideView** (`wp-content/themes/tideview`) — landing page + blog for the
  TideView video app. Ocean-dark design.

Both are standard, self-contained WordPress themes — activate whichever fits
the site (Appearance → Themes). They also work with LocalWP or any WordPress
host: copy the theme folder into `wp-content/themes/` and activate.

## What's here

```
wordpress/
├── docker-compose.yml            # WordPress 6.8 + MySQL 8, one-command local stack
└── wp-content/themes/tideview/   # Custom "TideView" theme
    ├── style.css                 # Theme metadata + all styling (ocean-dark design)
    ├── functions.php             # Theme supports, menus, enqueue
    ├── front-page.php            # Landing page: hero, features, download CTA, blog teaser
    ├── index.php                 # Blog index / archive / search results
    ├── single.php / page.php     # Post and page templates
    ├── 404.php / searchform.php  # Error page and search form
    ├── header.php / footer.php
    └── template-parts/content-card.php
```

## Run it locally

Requires Docker with the Compose plugin.

```bash
cd wordpress
docker compose up -d
```

Then:

1. Open http://localhost:8080 and run the 5-minute WordPress installer
   (pick your site title, admin user, and password).
2. In the admin dashboard go to **Appearance → Themes** and activate **TideView**.
3. The landing page appears automatically on the front page (`front-page.php`).
   To get a separate blog listing at `/blog`, create an empty page called
   "Blog" and set it as the Posts page under **Settings → Reading**.

The theme directory is bind-mounted into the container, so edits to files under
`wp-content/themes/tideview/` show up on refresh — no rebuild needed.

To stop: `docker compose down` (add `-v` to also wipe the database and start fresh).

## Deploying to a real host

The theme is standard, self-contained WordPress: zip the
`wp-content/themes/tideview` folder and upload it via
**Appearance → Themes → Add New → Upload Theme** on any WordPress host
(WordPress 6.0+, PHP 7.4+), then activate it.

## Customizing

- **Menus** — the header falls back to Features/Download/Blog anchor links until
  you assign a menu to the "Primary Menu" location (Appearance → Menus).
  A "Footer Menu" location is also registered.
- **Download links** — the buttons in `front-page.php` currently point to the
  GitHub repo; swap in Play Store / App Store URLs when you have them.
- **Colors** — all colors are CSS custom properties at the top of `style.css`
  (`--tv-accent`, `--tv-bg`, …); change them in one place.
