# Tá Justo? — CEASA-RJ Fair Price Index

**The first consumer pricing index for Rio de Janeiro.**

Tá Justo? turns CEASA-RJ's daily wholesale price bulletins into a fair-price
guide that any shopper at a feira or market can check in 3 taps.

One city, one source, one question: *tá justo?*

---

## What it does

Three surfaces:

1. **`/` — The Checker** — Pick a product, enter the R$/kg you're paying, and get
   a verdict: *Barato / Na média / Caro*, plus whether it's a good *época*
   (season) to buy.
2. **`/precos` — Today's CEASA Prices** — Today's atacado prices by section.
3. **`/produtos/:slug` — Product Detail** — Price history (in today's reais) and
   seasonality, with the verdict calculator inline.

Free, ad-free, no data selling. Not a SaaS — a portfolio project that's
genuinely useful.

## The data

All prices come from CEASA-RJ's official daily bulletins (Governo do Estado do
Rio de Janeiro). Coverage spans **2022 → today**: 1,000+ bulletins and 180k+
price quotes across ~170 products.

## How it works

Every business day we fetch the latest CEASA-RJ bulletin and normalize every
price to **R$/kg** — the unit you compare at the feira. (Eggs become per-dozen;
unit-sold fruits like pineapple use an average piece weight.) When you enter a
price, we compare it to wholesale, apply a typical feira markup (1.7–2.5×), and
tell you two things: whether the seller's margin is fair, and whether this is a
cheap or expensive *época* for that product.

## License

Portfolio project. Not for commercial use.

---

Desenvolvido por [Gustavo Neiva](https://gustavoneiva.dev).

**Built with care in Rio de Janeiro 🇧🇷**

> Contributors & agents: working notes and data caveats live in [`AGENTS.md`](AGENTS.md).
