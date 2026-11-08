// Mobile checker E2E — iPhone 13 viewport, Fast-3G throttling, counts taps.
// Proves: search → CEASA price in ≤ 2 taps, verdict in ≤ 3 taps; stall tile
// and recent chip → price in 1 tap; results sit above the on-screen keyboard;
// tap targets ≥ 44px.
//
// Needs a running server with CEASA data (dev DB is fine):
//   bin/rails s -p 3918
//   BASE_URL=http://localhost:3918 node test/e2e/checker_mobile.mjs
// Playwright is not a project dependency. Point at any install, e.g.
//   PLAYWRIGHT_MODULE=$(npm root -g)/@playwright/cli/node_modules/playwright/index.js
//   CHROME_PATH=<chromium-headless-shell binary> (if the bundled browser version differs)
import assert from "node:assert/strict"

const { chromium, devices } = (await import(process.env.PLAYWRIGHT_MODULE || "playwright")).default ?? await import(process.env.PLAYWRIGHT_MODULE || "playwright")
const BASE = process.env.BASE_URL || "http://localhost:3918"
const KEYBOARD_PX = 336 // iPhone portrait keyboard + suggestion bar

const browser = await chromium.launch(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {})
const context = await browser.newContext({ ...devices["iPhone 13"], locale: "pt-BR" })
const page = await context.newPage()
page.setDefaultTimeout(90_000)
const ready = () => page.waitForSelector("[data-controller=checker][data-ready]", { state: "attached" })
const cdp = await context.newCDPSession(page)
await cdp.send("Network.enable")
await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: 562, downloadThroughput: 180 * 1024, uploadThroughput: 84 * 1024 })
const errors = []
page.on("pageerror", e => errors.push(e.message))

let taps = 0
const tap = async selector => { taps++; await page.tap(selector) }
const visibleText = async sel => (await page.locator(sel).first().innerText()).replace(/\s+/g, " ")
const box = async sel => page.locator(sel).first().boundingBox()
const report = []
const step = (name, t0, extra = "") => report.push(`${name.padEnd(46)} taps=${taps}  ${((Date.now() - t0) / 1000).toFixed(1)}s ${extra}`)

// 1. Search path: "alface americana" (a type CEASA doesn't quote)
let t0 = Date.now()
await page.goto(BASE + "/", { waitUntil: "domcontentloaded" })
await ready()
step("cold load until search is live (Fast 3G)", t0)
t0 = Date.now(); taps = 0
await tap("#checker-q")
await page.keyboard.type("alface americana")
await page.waitForSelector(".checker-results .result")
const first = await box(".checker-results .result")
const viewport = page.viewportSize()
assert.ok(first.y + first.height <= viewport.height - KEYBOARD_PX, `first result (bottom ${first.y + first.height}px) hidden by keyboard`)
assert.ok(first.height >= 44, `result row ${first.height}px < 44px`)
assert.match(await visibleText(".checker-results .result"), /Alface.*referência mais próxima/)
await tap(".checker-results .result")
await page.waitForSelector("#item-alface:not([hidden])")
assert.match(await visibleText("#item-alface .item-ceasa"), /CEASA .*R\$ \d+,\d{2} por unidade/)
assert.ok(await page.isVisible("#item-alface [data-closest-note]"), "closest-reference note not shown")
const card = await box("#item-alface .item-fair")
assert.ok(card.y + card.height <= viewport.height, "fair price below the fold after pick")
assert.ok(taps <= 2, `price visible after ${taps} taps`)
step("search 'alface americana' → CEASA price", t0)

// 2. Verdict: type the sign's price with a comma
await tap("#item-alface .item-headline input[name=price]")
const priceBox = await box("#item-alface .item-headline input[name=price]")
assert.ok(priceBox.height >= 44)
assert.equal(await page.getAttribute("#item-alface .item-headline input[name=price]", "inputmode"), "decimal")
await page.keyboard.type("4,99")
await Promise.all([page.waitForURL(/price=4%2C99/), page.keyboard.press("Enter")])
await page.waitForSelector(".verdict-result .verdict-badge")
await ready()
assert.match(await visibleText(".verdict-result"), /Você pagou: R\$ 4,99\/unidade/)
assert.ok(taps <= 3, `verdict after ${taps} taps`)
step("… + price '4,99' → verdict (Enter key)", t0)

// 3. Stall tile path: no typing
t0 = Date.now(); taps = 0
await page.goto(BASE + "/", { waitUntil: "domcontentloaded" })
await ready()
await tap(".checker-grid .tile[data-item=tomate]")
await page.waitForSelector("#item-tomate:not([hidden])")
assert.match(await visibleText("#item-tomate"), /R\$ \d+,\d{2}/)
assert.equal(taps, 1)
const tile = await box(".checker-grid .tile")
assert.ok(tile.height >= 44 && tile.width >= 44, "tile smaller than 44px")
step("stall tile 'Tomate' → CEASA price", t0)

// 4. Recent chip: alface + tomate were opened above
t0 = Date.now(); taps = 0
await page.goto(BASE + "/", { waitUntil: "domcontentloaded" })
await ready()
assert.ok(await page.isVisible(".checker-recent .tile[data-item=alface]"), "recent chips missing")
await tap(".checker-recent .tile[data-item=alface]")
await page.waitForSelector("#item-alface:not([hidden])")
assert.equal(taps, 1)
step("recent chip 'Alface' → CEASA price", t0)

// 5. Variety matters: "banana prata" opens the Prata row directly
t0 = Date.now(); taps = 0
await tap("#checker-q")
await page.fill("#checker-q", "")
await page.keyboard.type("banana prata")
await page.waitForSelector(".checker-results .result")
await tap(".checker-results .result")
await page.waitForSelector("#item-banana details.variety[open]")
assert.match(await visibleText("#item-banana details.variety[open] summary"), /Prata.*R\$ \d+,\d{2}\/kg/)
assert.ok(taps <= 2)
step("search 'banana prata' → Prata price + math", t0)

assert.deepEqual(errors, [], "page errors")
console.log(report.join("\n"))
console.log("OK — all mobile checker assertions passed")
await browser.close()
