// Checker item search — pure functions, no DOM (unit-tested by
// test/javascript/checker_search_gold.mjs against the gold set).
//
// Every query word must start a word of the item (name, alias, variety label
// or a "closest" name). Name/alias hits outrank variety hits, so "maçã" finds
// Maçã before Banana › Maçã. If nothing matches every word (store-sign noise
// like "kg", "lavada", "un"), fall back to items matching the most words.

const WEIGHT = { name: 4, alias: 3, variety: 2, closest: 1 }

export function normalize(text) {
  return String(text).normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase().replace(/['’´`]/g, "")
}

export function tokens(text) {
  return normalize(text).split(/[^a-z0-9]+/).filter(Boolean).map(t => (t.length > 3 && t.endsWith("s") ? t.slice(0, -1) : t))
}

const phrase = text => tokens(text).join(" ")

export function prepare(items) {
  return items.map(item => {
    const words = []
    const add = (text, field, variety) => tokens(text).forEach(word => words.push({ word, field, variety }))
    add(item.name, "name")
    item.aliases?.forEach(a => add(a, "alias"))
    item.varieties?.forEach((v, i) => add(v, "variety", i))
    item.closest?.forEach(c => add(c, "closest"))
    const phrases = [item.name, item.name.split("(")[0], ...(item.aliases || [])].map(phrase)
    return { item, words, phrases }
  })
}

function score(entry, query, loose) {
  let total = 0, matched = 0, variety = null, closestOnly = false
  for (const q of query) {
    let best = null
    for (const w of entry.words) {
      const s = w.word === q ? WEIGHT[w.field] : w.word.startsWith(q) ? WEIGHT[w.field] - 0.5 : 0
      if (s > 0 && (!best || s > best.s)) best = { s, ...w }
      // a word naming a variety opens it, even when an alias scored higher ("mamão papaia")
      if (s > 0 && w.field === "variety" && q.length > 2) variety ??= w.variety
    }
    if (!best) { if (loose) continue; return null }
    total += best.s; matched++
    if (best.field === "closest") closestOnly = true
  }
  if (!matched) return null
  const q = query.join(" ")
  if (entry.phrases.includes(q)) total += 10
  else if (entry.phrases.some(p => p.startsWith(q))) total += 3
  if (entry.item.top) total += 0.25
  return { item: entry.item, score: total + matched * 5, variety, closest: closestOnly, loose }
}

export function search(prepared, text, limit = 6) {
  const query = tokens(text)
  if (!query.length) return []
  const rank = loose => prepared.map(e => score(e, query, loose)).filter(Boolean)
    .sort((a, b) => b.score - a.score || a.item.name.length - b.item.name.length)
  const strict = rank(false)
  return (strict.length ? strict : rank(true)).slice(0, limit)
}
