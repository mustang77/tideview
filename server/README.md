# Paramall backend (PHP + MySQL)

A tiny token-based API so accounts and orders are **real and cross-device**:
customers register/login on any phone, orders are stored on your server, and
your admin sees every order.

Runs on your existing Webuzo/LiteSpeed host — no new server needed.

## Endpoints

`POST https://paramall.h2olaundry.com/api/index.php` with JSON `{ "action": "...", ... }`

| action | auth | body | returns |
|--------|------|------|---------|
| `health` | — | — | `{ok:true}` (reachability, no DB) |
| `register` | — | name, phone, pin | token, name, phone |
| `login` | — | phone, pin | token, name, phone, address |
| `me` | token | — | name, phone, address |
| `save_profile` | token | name, address | ok |
| `place_order` | token | items[], subtotal, ongkir, total, addr, name, phone, note, pay, zone | id |
| `my_orders` | token | — | orders[] |
| `admin_orders` | admin_pass | — | all orders[] |
| `admin_set_status` | admin_pass | id, status | ok |
| `driver_orders` | driver_pass | — | active orders[] (not yet Selesai) |
| `driver_set_status` | driver_pass | id, status (Diantar/Selesai) | ok |
| `register_token` | token | device_token, platform | ok (for push) |
| `unregister_token` | — | device_token | ok |

Auth token goes in the JSON body as `token` (or `Authorization: Bearer <token>`).
Admin endpoints need `admin_pass`; driver endpoints need `driver_pass` (the admin
passcode also works for driver endpoints). Status changes send a push to the
customer, and new orders alert the `staff` topic — see **Push notifications** below.

## Setup (once, ~10 minutes)

1. **Create a database + user** in Webuzo → *MySQL Databases*. Note the DB name,
   user, and password (Webuzo usually prefixes them, e.g. `user_paramall`).
2. **Import the schema:** Webuzo → *phpMyAdmin* → select your DB → *Import* →
   upload `schema.sql`.
3. **Configure:** copy `api/config.sample.php` to `api/config.php` and fill in
   the DB name/user/password. (Leave `admin_pass` as `paramall2026` or change it.)
4. **Upload:** put the `api/` folder into your site so it serves at
   `paramall.h2olaundry.com/api/` (i.e. `paramall/api/index.php`). Upload
   `index.php` and `config.php` (not `config.sample.php`).
5. **Test:** open
   `https://paramall.h2olaundry.com/api/index.php?action=health`
   → you should see `{"ok":true,"service":"paramall-api",...}`.
   If you see a DB error on a `login` test, re-check `config.php`.

## Security notes

- PINs are hashed with `password_hash` (bcrypt); tokens are random 32-byte hex.
- All queries use prepared statements (no SQL injection).
- `config.php` holds your DB password — it is git-ignored; never share it.
- Always call over **https** (your site already has SSL).
- This is an MVP: consider adding rate-limiting and per-token expiry as you grow.

## Push notifications (Firebase Cloud Messaging)

Push is **optional** and off until you configure it — the API works fine without
it. To turn it on:

1. Create a free Firebase project (see `FIREBASE_SETUP.md` at the repo root for
   the full walkthrough).
2. In Firebase → *Project settings → Service accounts → Generate new private
   key*. Save the downloaded JSON as `api/fcm-service-account.json` (next to
   `index.php`). It is git-ignored — never commit it.
3. Put your Firebase **project id** into `config.php` as `fcm_project_id`.
4. Re-import `schema.sql` (or just run the `device_tokens` CREATE TABLE) so the
   token table exists.

That's it. `fcm.php` reads those two things; if either is missing it silently
no-ops. When present:
- changing an order's status pushes to that customer's devices, and
- a new order pushes to the `staff` topic (drivers/admins subscribe to it).

## Next: connect the app

Once `health` returns OK, the Flutter app gets pointed at this API so
register/login and orders go through the server instead of the phone's local
storage — that's the next step.
