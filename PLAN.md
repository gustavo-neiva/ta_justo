# PLAN.md — Tá Justo?: finish setup, sound code, green CI, deploy-ready + PWA

Tracker grammar: `[ ]` open → `[IN PROGRESS]` → `[x]` done. Tags: `(trivial|normal|hard)` and `(serial)`.

**Goal (rearticulated):** Take Tá Justo? from "data layer done, working tree staged-but-uncommitted, CI red" to
"green gate, clean CI, security CVEs patched, deploy config consistent (scaffold only — domain/droplet not yet
registered), installable app-like PWA, repo hygiene done." **Stop before mobile QA + real deploy.**

## Design constraints (read before ANY task — non-negotiable)
1. **Zero data regressions.** Modern bulletins (≥2023-03-01) and price counts must stay byte-identical. Every
   task that touches ingest/seed must confirm modern counts unchanged. (No task here re-ingests — but the guard holds.)
2. **VERIFY_CMD is the only "done" signal.** A task is done when `bin/rubocop && bin/rails test` is green AND the
   task's own verify command passes. No green, no commit.
3. **Ruby is 3.4.2 via asdf.** Shell PATH must include `$HOME/.asdf/shims` (system Ruby 2.6 breaks bundler).
4. **STAGE, don't commit/push**, unless explicitly told. (User reviews first.)
5. **No new dependencies for what a few lines do.** PWA uses Rails' built-in `rails/pwa` engine + vanilla SW.
6. **Hidden dirs stay out of git.** `.gitnexus/` and `.claude/` are not committed; their ignore rules live in the
   tracked `.gitignore` (currently `.gitnexus/` is only in local `.git/info/exclude`). GitNexus *usage docs* live in
   the committed `AGENTS.md` gitnexus block — that is how the config survives in the repo.

## VERIFY_CMD (the green gate — run after every task)
```bash
export PATH="$HOME/.asdf/shims:$PATH"
bin/rubocop && bin/rails test
```
Plus the full security scan before declaring M1 done: `bin/bundler-audit && bin/brakeman -q`.

## State at plan start (2026-07-24, verified live)
- 99 tests, **1 failure** (`fair_price_verdict_percentile_test.rb:46`: expects 92, gets 91 — wall-clock brittle).
- **5 RuboCop `Lint/Syntax` fatalities** — all from one bug: `db/seeds/price_indices.rb:54`
  `puts "   #{e.backtrace.first(5).join(\"\\n\")}"` → unparseable. `ruby -c` fails. File is `load`ed by
  `db/seeds.rb:21` → `rails db:seed` crashes on fresh prod setup. **Blocker.**
- RuboCop: 120 autocorrectable style offenses (spacing, quotes, trailing newlines).
- bundler-audit: **9 CVEs** → crass×4 (<1.0.7), loofah×3 (<2.25.2), rails-html-sanitizer (<1.7.1),
  websocket-driver (<0.8.2).
- Brakeman: 1 Medium — command injection `parser.rb:8` backtick `pdftotext -layout "#{pdf_path}" -` (pdf_path is
  internal Tempfile/archive path, low real risk, but CI-RED).
- Deploy: `config/deploy.yml` has placeholder IP `192.168.0.1` + `registry: localhost:5555`; never deployed.
  **Decision: leave as scaffold** (domain `tajusto.com.br` not registered, no droplet yet).
- PWA: `app/views/pwa/{manifest.json.erb,service-worker.js}` exist; routes **commented out**; manifest has
  placeholder `"theme_color":"red"` and `"name":"TaJusto"`; head already sets `<meta theme-color #035925>` and
  references `/icon-192.png` (missing — only `icon.png` 512×512 + `icon.svg` exist).
- Hidden-file hygiene: `.claude/skills/gitnexus/*` are **staged** (shouldn't be); `.gitnexus/` only ignored locally.

---

## Milestone 0 — green gate (serial: all touch the gate)
> No feature task runs before this is green.

- [x] T0.1 (trivial, serial) Fix the seed syntax error so `rails db:seed` can run
      touches: db/seeds/price_indices.rb
      do: Line 54 is `puts "   #{e.backtrace.first(5).join(\"\\n\")}"` — the escaped quotes inside interpolation
          are invalid Ruby. Change to `puts "  #{e.backtrace.first(5).join("\n")}"` (single straight quotes inside
          the double-quoted string). This is the only change. Reason: the file is unparseable and is `load`ed by
          `db/seeds.rb:21`, so prod seed crashes in the rescue branch.
      snippet:
          # before (broken)
          puts "   #{e.backtrace.first(5).join(\"\\n\")}"
          # after
          puts "  #{e.backtrace.first(5).join("\n")}"
      accept:
          Given db/seeds/price_indices.rb
          When `ruby -c db/seeds/price_indices.rb` runs
          Then it exits 0 (syntax OK)
      verify: ruby -c db/seeds/price_indices.rb && bin/rubocop db/seeds/price_indices.rb
      constraints: one-line change only; do not reformat the rest of the file

- [x] T0.2 (normal, serial) De-brittle the percentile test so it stops depending on today's date
      touches: test/services/fair_price_verdict_percentile_test.rb
      do: The test builds 12 fixed-date bulletins (2025-07-01..2026-06-01) but `Variant#representative_series`
          windows to `12.months.ago` from the real clock. As real-time advances past 2026-07-01, the oldest
          bulletin falls out of window → 11 samples → 10/11=91% not 92%. Fix by freezing the clock INSIDE the
          percentile assertions to a date where all 12 bulletins are within 12 months (e.g. `travel_to
          Date.new(2026,6,1)`). Keep the paid-independence test as-is. Reason: a test that flips red on the
          calendar is a flaky gate, not a code bug.
      snippet:
          test "per_unit percentile reflects today's CEASA position in the series" do
            travel_to(Date.new(2026, 6, 1)) do
              res = verdict_for(paid: 100.0)
              assert_equal 92, res.percentile_12m
            end
          end
      accept:
          Given the 12-bulletin setup
          When the test runs on any real-world date
          Then both percentile assertions pass deterministically
      verify: bin/rails test test/services/fair_price_verdict_percentile_test.rb
      constraints: use Rails `travel_to`; do not change app code (representative_series is correct)

- [x] T0.3 (trivial, serial) Establish the green gate
      do: Run VERIFY_CMD; confirm 99 runs, 0 failures, 0 rubocop fatalities. This is the baseline every later
          task must preserve.
      accept: Given M0.1+M0.2 applied, Then `bin/rubocop && bin/rails test` is fully green.
      verify: bin/rubocop && bin/rails test

## Milestone 1 — CI green (all four CI jobs pass)

- [x] T1.1 (normal, serial) Autocorrect the 120 style offenses
      touches: many files (autocorrect)
      do: Run `bin/rubocop -A`. RuboCop autocorrects spacing/quotes/trailing-newline only (safe). Then eyeball the
          diff for anything weird; nothing semantic should move. Reason: CI `lint` job runs `bin/rubocop -f github`
          and is RED until these are gone.
      accept: Given M0 applied, When `bin/rubocop -A` runs, Then `bin/rubocop` reports 0 offenses.
      verify: bin/rubocop
      constraints: safe-correct only; if RuboCop proposes an unsafe correction anywhere, skip that file and note it

- [x] T1.2 (hard, serial) Patch the 9 gem CVEs with a narrow bundle update
      touches: Gemfile.lock
      do: `bundle update crass loofah rails-html-sanitizer websocket-driver --conservative`. Targets: crass ≥1.0.7,
          loofah ≥2.25.2, rails-html-sanitizer ≥1.7.1, websocket-driver ≥0.8.2. These are transitive security deps;
          `--conservative` prevents pulling Rails itself forward. Re-run the full suite to confirm nothing broke.
          Reason: CI `scan_ruby` runs bundler-audit and is RED.
      accept:
          Given the locked vulnerable versions
          When bundle update runs
          Then `bin/bundler-audit` reports 0 vulnerabilities AND `bin/rails test` stays green
      verify: bin/bundler-audit && bin/rails test
      constraints: do not bump Rails majors/minors; if conservative update can't satisfy, report and stop

- [x] T1.3 (normal) Kill the Brakeman command-injection with the real fix (array-form popen)
      touches: app/services/ceasa_rio/parser.rb
      do: Line 8 uses a shell backtick: `` @text = `pdftotext -layout "#{pdf_path}" -` ``. `pdf_path` is always an
          internal Tempfile path or an archived path under `storage/ceasa/raw/` — never user input — so real risk is
          low, but the shell form is what Brakeman flags. Replace with the no-shell array form:
          `@text = IO.popen(["pdftotext", "-layout", pdf_path, "-"], err: "/dev/null", &:read)`. Identical output,
          no shell, warning gone. Reason: CI `scan_ruby` runs brakeman and is RED; this is the correct fix, not a
          suppression.
      snippet:
          # before
          @text = `pdftotext -layout "#{pdf_path}" -`
          # after
          @text = IO.popen(["pdftotext", "-layout", pdf_path, "-"], err: "/dev/null", &:read)
      accept:
          Given the parser is called with a fixture PDF path
          When `IO.popen` array form runs
          Then parsed output is byte-identical to today AND `bin/brakeman -q` reports 0 warnings
      verify: bin/rails test test/services/ceasa_rio/parser_test.rb test/jobs/ceasa_archive_flow_test.rb && bin/brakeman -q
      constraints: pdftotext is a hard dependency (AGENTS.md); keep behavior identical

## Milestone 2 — deploy config consistent (scaffold only — NO real deploy)
> Decision: domain not registered, no droplet. Keep deploy.yml as scaffold; just make it internally consistent and
> leave a documented next-step. Do not run `bin/kamal setup`.

- [x] T2.1 (trivial) Document the deploy scaffold + add a placeholder backup cron as a commented reminder
      touches: config/deploy.yml, STATUS.md
      do: deploy.yml already has `server: 192.168.0.1` + `registry: localhost:5555` placeholders — leave them. Only
          add a short `# TODO(prod)` comment block naming the three inputs needed when real (droplet IP, registry
          creds, domain `tajusto.com.br` + `proxy.ssl`). In STATUS.md, refresh the C3 Deploy section to reflect
          "scaffold ready, awaiting domain+droplet". Reason: keeps the scaffold honest and grep-able instead of
          looking accidentally-configured.
      accept: Given deploy.yml, When a new dev reads it, Then the three missing inputs + proxy.ssl are named in one
              place; no real server is contacted.
      verify: git diff --stat config/deploy.yml STATUS.md && bin/rails runner 'puts "boot ok"'
      constraints: never run kamal setup; never put a real secret in the file

## Milestone 3 — app-like PWA (installable, standalone, offline shell)
> The user wants this Rails app to run as a non-native PWA ("app-like"). Rails 8 ships the `rails/pwa` engine and
> scaffold views; they're just unwired. Wire them with real branding + an offline-fallback service worker.

- [x] T3.1 (normal, serial) Wire the PWA: routes + branded manifest + head links + offline SW + 192 icon
      touches: config/routes.rb, app/views/pwa/manifest.json.erb, app/views/pwa/service-worker.js,
               app/views/layouts/_head.html.erb, public/icon-192.png (new)
      do:
        1. routes.rb: uncomment the two PWA routes:
           `get "manifest" => "rails/pwa#manifest"` and `get "service-worker" => "rails/pwa#service_worker"`.
        2. manifest.json.erb: replace placeholder `"name":"TaJusto"` / `"theme_color":"red"` with real branding:
           name "Tá Justo?", short_name "Tá Justo", description from the app's purpose, theme_color "#035925",
           background_color "#fafafa", display "standalone", orientation "portrait", start_url "/", scope "/",
           lang "pt-BR". Icons: 192 (icon-192.png) + 512 (icon.png), both with a maskable entry.
        3. service-worker.js: add a minimal offline shell — on fetch, network-first for navigation, fall back to a
           cached "/" shell on failure; cache static GETs. Keep it tiny (offline-first-lite). No web push (not built).
        4. _head.html.erb: add `<link rel="manifest" href="/manifest.json">` (apple-touch-icon + theme-color
           already present). Add `<meta name="apple-mobile-web-app-status-bar-style" content="default">`.
        5. public/icon-192.png: generate from icon.png (512) with `sips -Z 192`.
      snippet (manifest core):
          {
            "name": "Tá Justo?",
            "short_name": "Tá Justo",
            "description": "Compare preços de feira com o atacado CEASA-RJ...",
            "lang": "pt-BR",
            "start_url": "/", "scope": "/", "display": "standalone", "orientation": "portrait",
            "theme_color": "#035925", "background_color": "#fafafa",
            "icons": [
              { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
              { "src": "/icon.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
            ]
          }
      accept:
          Given the app boots
          When GET /manifest.json and GET /service-worker are requested
          Then both return 200 with correct content-type AND the manifest validates as installable
          (name+short_name+icons 192+512+start_url+display standalone) AND the <head> links the manifest AND
          no existing route test breaks.
      verify: bin/rails test && bin/rails runner 'app=Rails.application; puts app.routes.url_helpers.path_to_route_helper?("manifest") rescue nil; require "net/http"; puts "routes OK"'
      constraints: no new gems; vanilla JS SW; do not break Turbo (SW must not intercept non-GET or Turbo streams aggressively)

## Milestone 4 — repo hygiene (hidden files out, ignore rules in)
- [x] T4.1 (trivial, serial) Unstage hidden dirs and commit the ignore rules instead
      touches: .gitignore
      do:
        1. Add to `.gitignore`: `/.claude/` and `/.gitnexus/` (move the latter's rule out of local `.git/info/exclude`
           into the tracked file so it survives across clones — this is how GitNexus config "lives in the repo").
        2. `git restore --staged .claude` to unstage the hidden skill docs.
        3. Confirm AGENTS.md's `<!-- gitnexus -->` usage block stays (that's the committed GitNexus documentation).
      accept:
          Given the current staged tree
          When gitignore is updated and .claude is unstaged
          Then `git status` shows no `.claude/` or `.gitnexus/` files staged, and the ignore rules are in the
          tracked `.gitignore` (visible to every clone).
      verify: git status --porcelain | grep -E '\.claude/|\.gitnexus/' && echo "FAIL: hidden staged" || echo "OK"; git check-ignore -v .gitnexus/meta.json .claude/CLAUDE.md
      constraints: do not delete AGENTS.md gitnexus block; do not remove .pi-loop.json.lock ignore

## Definition of done
- All tasks `[x]`.
- `bin/rubocop && bin/rails test` green.
- `bin/bundler-audit && bin/brakeman -q` clean.
- `rails db:seed` parses (seed syntax fixed).
- PWA installable (`/manifest.json` + `/service-worker` 200, real branding).
- Hidden files unstaged; ignore rules in tracked `.gitignore`.
- Deploy left as documented scaffold (no real deploy, per decision).
- Everything **staged** for the user to review (not committed).

## Non-goals (explicitly OUT)
- Real deploy / kamal setup / domain registration / droplet provisioning.
- Mobile QA (375px browser pass) — deferred.
- First real-feira field test.
- Web Push notifications.
- Parser edge-case unit-test expansion (post-deploy, per STATUS.md).
- Long-tail legacy `pending_matches` mapping (by design).
- Removing the `test/services/price_index_service_test.rb.bak` stray backup file (cosmetic; could sweep in T1.1).
