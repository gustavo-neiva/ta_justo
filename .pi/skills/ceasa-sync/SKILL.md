---
name: ceasa-sync
description: Fetch CEASA-RJ PDFs locally and sync+ingest them to the Hetzner ta_justo server. Use when the user says "sync ceasa", "update ta_justo prices", "ship ceasa to the server", "fetch ceasa", "run the ceasa pipeline", or wants the daily price refresh on tajusto.com.br.
---

# ceasa-sync

Refresh CEASA-RJ prices on the production server. The Hetzner box is **geo-blocked**
by PRODERJ (BR-only egress), so PDFs must be downloaded on this Mac (BR IP + poppler)
and shipped to the server for disk-only ingest.

## Prereqs (all true on this Mac)

- asdf ruby 3.4.2 at `~/.asdf/installs/ruby/3.4.2/bin` (the `/opt/homebrew` ruby shim is broken)
- `pdftotext` (poppler) on PATH
- SSH key auth to `root@167.233.175.179`
- Run **from the ta_justo repo root**: `~/Code/gustavo-neiva/ta_justo`

## The routine (two scripts, in order)

```bash
cd ~/Code/gustavo-neiva/ta_justo

# 1. Fetch locally → storage/ceasa/raw/ + local DB. Idempotent, skip-if-exists.
bin/ceasa_local_fetch.sh            # daily: grabs the single latest bulletin (FetchCeasaRioJob)
bin/ceasa_local_fetch.sh backfill   # reconcile: crawl site, fetch only MISSING bulletins (BackfillCeasaRioJob)

# 2. Ship to server + ingest (disk-only, idempotent)
bin/ceasa_sync_hetzner.sh
```

`backfill` is the superset — it crawls the site and fetches only what's missing, so it's
safe to run any time. Prefer **daily** for the routine refresh; reach for **backfill** when
the daily leaves a gap (missing weekdays) or to reconcile history.

## What each script does (don't reimplement — the scripts own this)

- `ceasa_local_fetch.sh` → `bin/rails runner "<Job>.perform_now"`, then prints
  `archive: N PDFs, latest bulletin YYYY-MM-DD`.
- `ceasa_sync_hetzner.sh` → `rsync -az storage/ceasa/raw/ → server volume`,
  `chown -R 1000:1000`, then `docker exec <web> bin/rails ceasa:ingest_archive`.
  Server path: `/var/lib/docker/volumes/ta_justo_storage/_data/ceasa/raw`.
  Container resolved at runtime via `docker ps | grep ta_justo | grep -v queue`.

## Verify the server actually got the new prices

Quote-escaping through 3 layers (bash → ssh → docker exec → rails runner) breaks on
embedded quotes — pipe Ruby via stdin instead:

```bash
SERVER="root@167.233.175.179"
C="$(ssh $SERVER "docker ps --format '{{.Names}}' | grep ta_justo | grep -v queue | head -1")"
ssh $SERVER "docker exec -i $C bin/rails runner /dev/stdin" <<'RUBY'
puts "server latest bulletin: #{Bulletin.where(market: 'ceasa-rj').maximum(:price_date)}"
puts "server bulletins:       #{Bulletin.where(market: 'ceasa-rj').count}"
puts "server prices:          #{Price.count}"
puts "server archive PDFs:    #{Dir['/rails/storage/ceasa/raw/*.pdf'].size}"
RUBY
```

Server is current when `latest bulletin` matches what the local fetch reported.

## Gotchas (hard-won — respect these)

- **rsync "0 transferred" + "Ingested 0" is the normal steady state** when nothing's new —
  not a failure. CEASA publishes weekdays only; the latest is often a day or two behind
  "today". Re-run later once they post.
- **`ls -t storage/ceasa/raw/*.pdf` reads mtime, not the date in the filename.** A file
  downloaded weeks ago has an old mtime even if its name is recent — this *looks* like a
  gap but isn't. Trust the script's `latest bulletin` line and the DB, not mtime.
- **Idempotent by design.** Re-running either script is always safe (bulletins dedup on
  `(market, price_date)`; prices skip if `(bulletin, variant, raw_unit)` exists).
- **Never commit fetched PDFs or run git** as part of this — it's a pure ops run, repo
  stays clean. STAGE-only workflow per global rules; nothing here touches the repo anyway.
- **Daily only grabs the single latest bulletin.** If several weekdays are missing, use
  `backfill` — it reconciles the whole gap in one pass.
