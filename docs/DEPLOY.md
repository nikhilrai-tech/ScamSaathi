# Running the API

A small server is enough for a pilot with a few institutions: **1 CPU, 1 GB memory, a domain name, Docker.** The API serves signed rule packs, the community scam list,
anonymous reports, "this result is wrong" messages, organisation alerts, and the organisation dashboard at `/org/`.

> **What has and has not been verified.** On a developer machine, with Docker Compose, the stack below was started and checked: HTTPS through Caddy (with its local
> certificate), HTTP redirected to HTTPS, the signed pack served, the dashboard served with its Content-Security-Policy, the admin site refused for addresses outside the
> allow-list and working for allowed ones (no CSRF error behind the proxy), and Caddy's logs carrying no IP addresses. It has **not** been run on a public server with a real
> domain and a real Let's Encrypt certificate, and **not** under load. SQLite is used: fine for a pilot, not for heavy traffic.

## 1. Before you start

- A domain (or subdomain) such as `api.example.org` with an A record pointing at the server. Ports 80 and 443 open.
- Docker and the Docker Compose plugin on the server.
- On **your own machine** (never the server): the repository, and the rule-pack signing key `~/.scamsaathi/release.key` (see `tools/packsign.py`). The server never needs the private key.

## 2. Put the files on the server

```bash
git clone https://github.com/nikhilrai-tech/ScamSaathi && cd ScamSaathi
cp deploy/env.example deploy/.env && nano deploy/.env        # DOMAIN, a long random SCAMSAATHI_SECRET_KEY (openssl rand -hex 32), ADMIN_ALLOW = your own IP
```

## 3. Sign the pack on your machine and copy it over

```bash
python tools/packsign.py sign --private ~/.scamsaathi/release.key --pack packs/core/pack.json
scp packs/core/pack.json packs/core/pack.sig.json server:ScamSaathi/packs/core/
```

The API refuses (503) to serve a pack whose signature is missing or does not match. Nothing needs restarting: the files are read on every request.

## 4. Start it

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec api python manage.py createsuperuser
curl https://api.example.org/healthz            # {"status": "ok"}
curl https://api.example.org/v1/packs/core/manifest
```

Migrations run when the container starts. `/admin/` answers only to the addresses in `ADMIN_ALLOW`; everyone else gets a 404.

## 5. Point the app at it

Build the app with the address: `flutter build apk --dart-define=SCAMSAATHI_API=https://api.example.org`. Without it the app is fully offline (no updates, no scam list, no reports).

## 6. Add an organisation

Check an organisation yourself first (call them, meet them). Then:

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec api \
  python manage.py createorg --name "Nashik Farmers Producer Co." --slug nashik-fpo --district nashik --kind fpo --verified
```

The API key is shown **once**; give it to them privately. Only its hash is stored. They sign in at `https://api.example.org/org/`.
To withdraw access, set the organisation inactive in the admin site.

## 7. Reviewing "this result is wrong" messages

People can send a message the app got wrong ([PRIVACY.md](PRIVACY.md) says exactly what is stored). In the admin site open **Donations**, read each one, and **reject** anything that
still identifies a person (names, addresses, a number that slipped through). **Accept** the rest. Then, on the server:

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec api python manage.py export_donations --out /data/donated.jsonl
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env cp api:/data/donated.jsonl ./donated.jsonl
python tools/train_model.py --sets benchmark heldout heldout2 heldout3 everyday ./donated.jsonl      # report only; add --write to put the model in the pack
```

This is real people's data. **Never commit `donated.jsonl`**, keep it off shared drives, and delete it when you are done. Measure a new model on a fresh set ([EVALUATION.md](EVALUATION.md)) before shipping it.

## 8. Retention, backups, updates

- **Retention.** Run `manage.py purge_donations` regularly (for example weekly from cron): it deletes rejected messages and messages nobody reviewed within 30 days, and never touches accepted ones.
  Use `--dry-run` first. This repository sets no other retention limit, so decide yours and write it in your privacy notice.
- **Logs.** Caddy is configured not to log IP addresses or request headers. The API writes access lines to the container log; keep that log short (`docker compose logs` rotates with Docker's defaults, or set a `max-size`).
- **Backups.** The database is `/data/db.sqlite3` in the `api-data` volume. A safe copy while running:

  ```bash
  docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec api python -c \
    "import sqlite3; s=sqlite3.connect('/data/db.sqlite3'); d=sqlite3.connect('/data/backup.sqlite3'); s.backup(d); d.close()"
  docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env cp api:/data/backup.sqlite3 ./backup-$(date +%F).sqlite3
  ```

  Keep backups as carefully as the data itself.
- **Updates.** Set `SCAMSAATHI_VERSION` in `deploy/.env` to the new release and run `docker compose ... pull && docker compose ... up -d`.
- **Monitoring.** `GET /healthz` is the health check; point any uptime monitor at it.

## 9. Before you tell the public

Have a lawyer review [PRIVACY.md](PRIVACY.md) for India's DPDP Act, 2023; decide who the operator is and how people reach them; keep the admin allow-list tight; and run the
test suites in the repository (`api/`, `e2e/`) after any change. Check the numbers in [EVALUATION.md](EVALUATION.md) before you describe what the app can do.
