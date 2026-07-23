# Coral Dash — Self-Hosted

Deploy [Coral Dash](https://coraldash.com) on your own server with Docker Compose. One-time £30 licence, no subscriptions. Your financial data never leaves your hardware.

**[Purchase a licence](https://coraldash.com/self-hosting)** to get started.

---

## What's included

- Google Sheets auto-sync (daily scheduled)
- Trading 212 portfolio sync
- Expense & income tracking with budgets
- Net worth & debt tracking
- Mortgage tracker (manual entry)
- Bundled Supabase stack (PostgreSQL, GoTrue auth, PostgREST, Kong)
- Multi-arch Docker images (amd64/arm64)

## Privacy

Coral Dash makes **exactly one outbound call** — on first boot, to activate your licence key against `coraldash.com`. After that, the app runs fully offline. No telemetry, no analytics, no phone-home. You can firewall the container after activation.

---

## Prerequisites

- **Docker** and **Docker Compose** v2+
- A **domain name** with DNS pointed to your server — needed for Google sign-in,
  HTTPS, and production use; a LAN trial works without one (see step 5)
- A **Google Cloud project** with OAuth credentials — required for Google Sheets sync; also enables "Continue with Google" login (email/password login needs no extra setup)
- A **licence key** — [purchase here](https://coraldash.com/self-hosting), then copy from your [account settings](https://coraldash.com/settings)

## Quick Start

### 1. Clone this repo

```bash
git clone https://github.com/coraldash/self-hosted.git coraldash
cd coraldash
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and fill in:

```env
LICENSE_KEY=your-uuid-licence-key
SITE_URL=https://coraldash.yourdomain.com
POSTGRES_PASSWORD=<generate with: openssl rand -hex 24>
JWT_SECRET=<generate with: openssl rand -base64 32>
GOOGLE_OAUTH_CLIENT_ID=your-google-client-id
GOOGLE_OAUTH_CLIENT_SECRET=your-google-client-secret
ALLOWED_EMAIL=you@gmail.com
CRON_SECRET=<generate with: openssl rand -hex 16>
```

> **Note:** `POSTGRES_PASSWORD` must contain only letters and digits — it is embedded
> in `postgres://` connection URLs, so characters like `/ + @ : # ?` break the stack
> (base64 output usually contains `/` or `+`). `openssl rand -hex 24` is safe. Also
> note `.env` files are read literally: run the `openssl` commands in your terminal
> and paste the output — `$(...)` is not executed inside `.env`.

### 3. Generate Supabase keys

```bash
chmod +x docker/generate-keys.sh
./docker/generate-keys.sh
```

The script reads `JWT_SECRET` from your `.env` (you can also pass the secret as an
argument). Copy the output `ANON_KEY` and `SERVICE_ROLE_KEY` into your `.env`.

### 4. Start the stack

```bash
docker compose up -d
```

On first boot, the container activates your licence key (single HTTPS call to `coraldash.com`). After that, it runs fully offline.

> **Just trying it out?** From v3.1.1 you can skip step 5 entirely: set
> `SITE_URL=http://your-server-ip:3000` in `.env`, open that address, and create
> an account with email and password. The app routes the Supabase API internally.
> A domain, HTTPS, and the reverse proxy are only needed for Google sign-in and
> production use.

### 5. Set up a reverse proxy (for Google sign-in and production)

You need HTTPS for Google OAuth. The reverse proxy must route **both** the app and the Supabase API through the same domain:

```
# /etc/caddy/Caddyfile
coraldash.yourdomain.com {
    handle /auth/v1/* {
        reverse_proxy localhost:8000
    }
    handle /rest/v1/* {
        reverse_proxy localhost:8000
    }
    handle {
        reverse_proxy localhost:3000
    }
}
```

Example configs for [Caddy](docker/Caddyfile.example) and [Nginx](docker/nginx.conf.example) are included.

### 6. Sign in

Visit `https://coraldash.yourdomain.com` and either **Continue with Google** or
create an account with **email and password** — both work out of the box. See
[Email/Password Login](#emailpassword-login) for details and optional lockdown.

---

## Google OAuth Setup

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Create a new **OAuth 2.0 Client ID** (Web application)
3. Add authorized redirect URI: `https://coraldash.yourdomain.com/auth/v1/callback`
4. Enable the **Google Drive API** (for Sheets sync)
5. Copy the Client ID and Client Secret to your `.env`

---

## Email/Password Login

Accounts can sign in with **Google** or with an **email address and password** —
both appear on the login page. Email/password is the easiest option if you'd
rather not wire up Google OAuth just for sign-in (you still need Google for Sheets
sync).

### Works out of the box

Email/password signup needs **no mail server**. New accounts are auto-confirmed
and signed in immediately — ideal for a private instance.

### Optional: email confirmation & password reset

To require new users to confirm their email, and to enable "forgot password"
reset links, configure SMTP (any provider works):

1. Set the `SMTP_*` variables in `.env`:

   ```env
   SMTP_HOST=smtp.resend.com
   SMTP_PORT=465
   SMTP_USER=resend
   SMTP_PASS=your-smtp-password-or-api-key
   SMTP_SENDER_EMAIL=auth@yourdomain.com
   ```

2. In `docker-compose.yml`, uncomment the `GOTRUE_SMTP_*` lines under the `auth`
   service and set `GOTRUE_MAILER_AUTOCONFIRM: "false"`.
3. Restart: `docker compose up -d`

Without SMTP the "forgot password" link will report that the email couldn't be
sent — that's expected, and both login methods still work.

### Lock down to your account only

By default, anyone who can reach your URL can create an account (this was already
true for Google sign-in). For a single-user instance, create your account first,
then disable new signups by adding this to the `auth` service in
`docker-compose.yml` and restarting:

```yaml
GOTRUE_DISABLE_SIGNUP: "true"
```

Existing users can still log in; no new accounts (Google **or** email) can be
created.

---

## Updating

```bash
git pull                        # picks up compose/config fixes
docker compose pull coraldash   # picks up the latest app image
docker compose up -d
```

If `git pull` changed `docker-compose.yml`, `docker compose up -d` recreates the
affected containers (a brief restart; your data volume is untouched). If you have
edited `docker-compose.yml` locally (SMTP, signup lockdown), stash your changes
first: `git stash && git pull && git stash pop`.

Migrations run automatically on startup. Back up your database before updating:

```bash
docker compose exec db pg_dump -U postgres postgres > backup-$(date +%Y%m%d).sql
```

---

## Backups

```bash
# Manual backup
docker compose exec db pg_dump -U postgres postgres > backup.sql

# Restore
cat backup.sql | docker compose exec -T db psql -U postgres postgres
```

We recommend setting up automated daily backups with cron.

---

## Server Migration

If you need to move to a new server:

1. Log in to [coraldash.com/settings](https://coraldash.com/settings) and click **Deactivate** on your licence
2. Back up your database: `docker compose exec db pg_dump -U postgres postgres > backup.sql`
3. Set up the new server following the Quick Start above (same `.env`, same licence key)
4. Restore your database: `cat backup.sql | docker compose exec -T db psql -U postgres postgres`

Your licence key reactivates on first boot of the new instance.

---

## Supabase Studio (optional)

For database debugging:

```bash
docker compose --profile debug up -d
```

Access at `http://your-server:3100`. Not recommended for production.

---

## Troubleshooting

### Container won't start — licence error

- Verify `LICENSE_KEY` in `.env` is a valid UUID (e.g., `xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx`)
- Your server needs outbound HTTPS to `coraldash.com` on first boot only
- If already activated on another instance, [deactivate it first](https://coraldash.com/settings)

### "dependency failed to start: container coraldash-rest-1 is unhealthy"

A bug in copies of `docker-compose.yml` downloaded before 22 July 2026: the health
probe for the `rest` (PostgREST) container needed a shell that does not exist
inside that image on amd64 servers, so Docker could never mark it healthy and
startup aborted. An `auth` error tile alongside it is usually just fallout from
the aborted startup.

```bash
git pull
docker compose up -d
```

To patch by hand instead: in `docker-compose.yml`, delete the `healthcheck:` block
under `rest:`, and under the `kong:` service's `depends_on:` change the `rest:`
condition from `service_healthy` to `service_started`.

If you already patched the file by hand, `git pull` will refuse over the local
change — run `git checkout -- docker-compose.yml` first (the pulled fix replaces
your patch).

After the fix, `docker compose ps` shows `db`, `auth` and `kong` as `healthy` and
`rest` as plain `Up` — that is by design (the image has no shell to run a probe).

### "Method Not Allowed" when signing in or creating an account

Seen on versions before v3.1.1 when the browser's auth requests reached the app
instead of the API gateway. Update the image:

```bash
docker compose pull coraldash
docker compose up -d
```

From v3.1.1 the app routes `/auth/v1/*` and `/rest/v1/*` itself, so email/password
sign-in needs no reverse proxy. Also make sure `SITE_URL` in `.env` exactly
matches the address in your browser's address bar (rerun `docker compose up -d`
after changing it).

### "password authentication failed" / auth restart-looping

The database volume keeps the password it was first created with. If you changed
`POSTGRES_PASSWORD` after an earlier `docker compose up` attempt, the new value no
longer matches. If setup never completed there is no data to lose:

```bash
docker compose down -v   # deletes the database volume
docker compose up -d
```

Also make sure the password contains only letters and digits — characters like
`/ + @ :` break the connection URLs (see the note in Quick Start step 2).

### Google OAuth redirect error

Ensure your redirect URI in Google Cloud Console exactly matches:
```
https://your-domain/auth/v1/callback
```

### Database connection issues

```bash
docker compose ps
docker compose logs db
```

Check that `POSTGRES_PASSWORD` is consistent across your `.env`. If the `auth` or
`rest` logs show `password authentication failed`, see the entry above — the
database volume remembers the password it was created with.

### Sync not running

```bash
docker compose logs coraldash | grep Cron
```

Default schedule is `0 6 * * *` (6am UTC). Customise with `SYNC_SCHEDULE` in `.env`.

### Unraid

Coral Dash runs fine on Unraid with the **Compose Manager** plugin — nothing in
the stack is Unraid-specific:

- Keep `docker-compose.yml`, `.env`, and the `docker/` folder together in the
  stack directory.
- First boot on HDD arrays can take 2-3 minutes while the database initialises;
  the health checks allow for this.
- If a container shows an **Error** tile, the reason is in its logs:
  `docker compose logs <service>` (e.g. `rest`, `auth`).
- Seeing `studio` and `meta` containers means the optional `debug` profile is
  enabled — they are harmless and not required.

### Reset everything

> **Warning:** This deletes all data.

```bash
docker compose down -v
docker compose up -d
```

---

## Architecture

```
                    ┌─────────────┐
                    │   Caddy /   │
                    │   Nginx     │  :443 (HTTPS)
                    └──┬──────┬──┘
                       │      │
          /auth/v1/*   │      │  /*
          /rest/v1/*   │      │
                       │      │
                 ┌─────▼──┐ ┌─▼──────────┐
                 │  Kong  │ │ Coral Dash  │
                 │  :8000 │ │ :3000       │
                 └──┬──┬──┘ │ + Cron      │
                    │  │    └──────┬──────┘
          ┌────────▼┐ ├▼────────┐  │
          │ GoTrue  │ │PostgREST│  │
          │  :9999  │ │  :3000  │  │
          └────┬────┘ └────┬────┘  │
               └─────┬─────┘       │
               ┌─────▼─────┐       │
               │ PostgreSQL │◄──────┘
               │   :5432    │
               └────────────┘
```

---

## Support

- **Roadmap & Changelog:** [coraldash.com/roadmap](https://coraldash.com/roadmap) — see all fixes and upcoming features
- **Found a bug?** [Open an issue on GitHub](https://github.com/coraldash/self-hosted/issues)
- **Purchase:** [coraldash.com/self-hosting](https://coraldash.com/self-hosting)
- **Account:** [coraldash.com/settings](https://coraldash.com/settings)

---

## Licence

Coral Dash is proprietary software. The self-hosted Docker image is distributed under a per-user licence. See [coraldash.com/terms](https://coraldash.com/terms) for details.
