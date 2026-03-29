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
- A **domain name** with DNS pointed to your server
- A **Google Cloud project** with OAuth credentials (for Google login + Sheets sync)
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
POSTGRES_PASSWORD=<generate a strong password>
JWT_SECRET=<generate with: openssl rand -base64 32>
GOOGLE_OAUTH_CLIENT_ID=your-google-client-id
GOOGLE_OAUTH_CLIENT_SECRET=your-google-client-secret
ALLOWED_EMAIL=you@gmail.com
CRON_SECRET=<generate with: openssl rand -hex 16>
```

### 3. Generate Supabase keys

```bash
chmod +x docker/generate-keys.sh
./docker/generate-keys.sh "$JWT_SECRET"
```

Copy the output `ANON_KEY` and `SERVICE_ROLE_KEY` into your `.env`.

### 4. Start the stack

```bash
docker compose up -d
```

On first boot, the container activates your licence key (single HTTPS call to `coraldash.com`). After that, it runs fully offline.

### 5. Set up a reverse proxy

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

Visit `https://coraldash.yourdomain.com` and sign in with Google.

---

## Google OAuth Setup

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Create a new **OAuth 2.0 Client ID** (Web application)
3. Add authorized redirect URI: `https://coraldash.yourdomain.com/auth/v1/callback`
4. Enable the **Google Drive API** (for Sheets sync)
5. Copy the Client ID and Client Secret to your `.env`

---

## Updating

```bash
docker compose pull coraldash
docker compose up -d
```

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

Check that `POSTGRES_PASSWORD` is consistent across your `.env`.

### Sync not running

```bash
docker compose logs coraldash | grep Cron
```

Default schedule is `0 6 * * *` (6am UTC). Customise with `SYNC_SCHEDULE` in `.env`.

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

- **Issues:** [github.com/coraldash/self-hosted/issues](https://github.com/coraldash/self-hosted/issues)
- **Purchase:** [coraldash.com/self-hosting](https://coraldash.com/self-hosting)
- **Account:** [coraldash.com/settings](https://coraldash.com/settings)

---

## Licence

Coral Dash is proprietary software. The self-hosted Docker image is distributed under a per-user licence. See [coraldash.com/terms](https://coraldash.com/terms) for details.
