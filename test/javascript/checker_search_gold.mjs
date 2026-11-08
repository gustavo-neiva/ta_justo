// Usage: node test/javascript/checker_search_gold.mjs <index.json> <gold.json>
// Prints one JSON line per query: {set, q, expected, hit, top3}.
// The scorer is loaded from source via a data: URL so this runs on any Node
// version without a package.json or ESM flags.
import fs from "node:fs"

const src = fs.readFileSync(new URL("../../app/javascript/lib/checker_search.js", import.meta.url), "utf8")
const { prepare, search } = await import("data:text/javascript;base64," + Buffer.from(src).toString("base64"))
const [indexPath, goldPath] = process.argv.slice(2)
const items = JSON.parse(fs.readFileSync(indexPath, "utf8"))
const gold = JSON.parse(fs.readFileSync(goldPath, "utf8")).queries
const prepared = prepare(items)

for (const [set, q, id, variety] of gold) {
  const top3 = search(prepared, q, 3)
  const hit = top3.some(r => r.item.id === id &&
    (variety === null || r.item.varieties[r.variety] === variety || r.item.varieties.length === 1))
  console.log(JSON.stringify({ set, q, expected: variety ? `${id} › ${variety}` : id, hit,
    top3: top3.map(r => r.item.id + (r.variety != null ? ` › ${r.item.varieties[r.variety]}` : "") + (r.closest ? " ≈" : "") + (r.loose ? " ~" : "")) }))
}
