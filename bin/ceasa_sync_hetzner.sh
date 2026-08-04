#!/usr/bin/env bash
# Ship locally-archived CEASA PDFs to Hetzner, then ingest disk-only (idempotent,
# no network — the server is geo-blocked). Archive-first invariant preserved:
# every PDF is on the server's disk before ceasa:ingest_archive parses it.
#
# Requires the deployed image to have poppler-utils (Dockerfile) + the
# ceasa:ingest_archive rake task. Run bin/ceasa_local_fetch.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."

SERVER="${CEASA_SERVER:-root@167.233.175.179}"
VOL="/var/lib/docker/volumes/ta_justo_storage/_data/ceasa/raw"

echo "==> rsync $(ls storage/ceasa/raw/ | wc -l | tr -d ' ') local PDFs -> $SERVER"
# rsync only new/changed; server writes are chowned to the rails uid (1000)
rsync -az --info=stats1 storage/ceasa/raw/ "$SERVER:$VOL/"
ssh "$SERVER" "chown -R 1000:1000 $VOL"

echo "==> ingest archive on server (disk-only, idempotent)"
C="$(ssh "$SERVER" "docker ps --format '{{.Names}}' | grep ta_justo | grep -v queue | head -1")"
ssh "$SERVER" "docker exec $C bin/rails ceasa:ingest_archive"
