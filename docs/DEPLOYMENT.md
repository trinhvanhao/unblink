# Deployment Notes (AI Runbook)

This file documents what worked in production for `zapdos-labs/unblink` on this VM, including pitfalls and verified commands.

## Current Production Shape

- Reverse proxy: Traefik (external, already running on host)
- App domain: `app.zapdoslabs.com`
- Runtime: Docker Compose
- App container: `unblink-app`
- App networking: `network_mode: host`
- App listen port: `VITE_SERVER_API_PORT=8090`
- Traefik backend target: `http://172.17.0.1:8090`
- Data persistence: named volume `unblink_unblink-data` mounted at `/home/appuser/.unblink`

## Why Host Networking Was Needed

WebRTC camera sessions failed with Docker bridge NAT (ICE `failed/disconnected`).
Switching `unblink-app` to host networking fixed the transport path for this environment.

## Files That Matter

- App env: `./.env`
- Compose: `./docker-compose.yml`
- Traefik dynamic route (outside repo): `/home/tri/dynamic/unblink.yml`

## One-Time Setup

1. Clone and configure env:

```bash
git clone git@github.com:zapdos-labs/unblink.git
cd unblink
# provide .env values
```

2. Ensure Traefik route exists on host (`/home/tri/dynamic/unblink.yml`) with `app.zapdoslabs.com` -> `http://172.17.0.1:8090`.

3. Start app:

```bash
sudo docker compose -f ./docker-compose.yml --env-file ./.env up -d --build
```

## Normal Redeploy (latest main)

```bash
git pull --ff-only origin main
sudo docker compose -f ./docker-compose.yml --env-file ./.env up -d --build
```

Expected: brief downtime while `unblink-app` is recreated.

## Health Checks

```bash
sudo docker ps --format '{{.Names}}\t{{.Status}}'
curl -s -H 'Host: app.zapdoslabs.com' http://127.0.0.1/health
curl -I https://app.zapdoslabs.com/
```

Healthy signals:

- `unblink-app` is `Up ... (healthy)`
- `/health` returns `OK`
- HTTPS returns `200`

## TLS / Cert Notes

- If browser shows "Not secure", check cert served:

```bash
echo | openssl s_client -servername app.zapdoslabs.com -connect app.zapdoslabs.com:443 2>/dev/null | openssl x509 -noout -subject -issuer
```

- Correct result should be Let's Encrypt issuer (not `TRAEFIK DEFAULT CERT`).
- During ACME issuance, short-lived browser cache weirdness can happen even after cert is fixed.

## Compose + .env Pitfall (Important)

If a secret contains `$`, Compose interpolates it unless escaped/quoted correctly.

- Broken behavior observed: `JWT_SECRET=k$_O...` got mangled by Compose variable interpolation.
- Working value in `.env`:

```env
JWT_SECRET='k$_O<}Nir>sqR?!92Sj;&5L;sP'
```

Validate resolved config before deploy:

```bash
docker compose -f ./docker-compose.yml --env-file ./.env config
```

## Persistence Notes

`unblink_unblink-data` stores app-dir data, especially saved frame files under:

- `/home/appuser/.unblink/storage/frames/<serviceID>/<frameID>.jpg`

Primary relational data is in external Postgres (Neon) from `DATABASE_URL`.

## Git Remote Notes

- Use SSH remote for push from this VM:

```bash
git remote set-url origin git@github.com:zapdos-labs/unblink.git
```

- If push rejected (remote advanced), do:

```bash
git pull --rebase origin main
git push origin main
```

## Fast Troubleshooting

1. App up but camera blank:
   - check browser webrtc internals for ICE `failed`
   - verify app is host-networked
2. App unhealthy:
   - `sudo docker logs --tail 200 unblink-app`
3. TLS warning:
   - verify cert subject/issuer and Traefik logs
4. Auth issues after deploy:
   - run `docker compose ... config` and confirm secrets were not interpolated incorrectly
