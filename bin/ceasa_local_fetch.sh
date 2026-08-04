#!/usr/bin/env bash
# Run the REAL CEASA pipeline locally. This Mac has the three things the
# geo-blocked Hetzner box lacks: a Brazilian egress IP (passes PRODERJ),
# poppler/pdftotext, and the full Rails app. So we just run the actual jobs
# here — no reimplementation. Result lands in storage/ceasa/raw/ + local DB.
# Ship PDFs to the server with bin/ceasa_sync_hetzner.sh.
#
#   bin/ceasa_local_fetch.sh          # daily forward fetch (FetchCeasaRioJob)
#   bin/ceasa_local_fetch.sh backfill # reconcile history (BackfillCeasaRioJob)
set -euo pipefail
cd "$(dirname "$0")/.."

# asdf ruby (the /opt/homebrew ruby shim is broken on this machine)
export PATH="$HOME/.asdf/installs/ruby/3.4.2/bin:$PATH"

case "${1:-daily}" in
  daily)    JOB=FetchCeasaRioJob ;;
  backfill) JOB=BackfillCeasaRioJob ;;
  *) echo "usage: $0 [daily|backfill]"; exit 1 ;;
esac

echo "==> running $JOB locally (BR egress + poppler + local DB)"
bin/rails runner "$JOB.perform_now"
bin/rails runner 'puts "archive: #{Dir[CeasaRio::Archiver.raw_dir.join(%q{*.pdf})].size} PDFs, latest bulletin #{Bulletin.where(market:%q{ceasa-rj}).maximum(:price_date)}"'
