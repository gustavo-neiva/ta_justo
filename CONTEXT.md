# Context Glossary — Tá Justo?

Ubiquitous language for the project. Glossary only — no implementation details.

## Bounded contexts

- **Ingestion** — turns CEASA-RJ PDF bulletins into stored price data.
  Terms: Bulletin, Price, Variant, Product, ProductMap, ProductAlias, PendingMatch.
- **Fair Price** — judges whether a price a shopper pays is fair, and whether the
  commodity itself is cheap right now. Terms below.

---

## Fair Price context

### Reference Price
The wholesale (atacado) CEASA quote(s) for a Variant on a given Bulletin, **and** the
single comparable value derived from it (R$/kg, R$/dúzia, or R$/unidade depending on
the Variant's pricing mode). Owns two things a shopper never sees separately today:
the **raw** quote (e.g. "Cx 15 kg → R$ 60,00, faixa 50–65") and the **translation**
into a comparable unit. When a Variant has several packing sizes on the same Bulletin,
the Reference Price selects one **representative** row (smallest retail pack) — this
choice is the single source of truth shared by every judgment.

### Price History
The trailing-12-month series of Reference Prices for a Variant, expressed in **real
terms** (deflated to the latest published index month). The basis for judging market
timing. Considered too thin to judge below ~30 samples.

### Price Index
A monthly consumer price index used to deflate nominal prices to real terms. Two are
tracked, both IBGE número-índice (level) series via BCB SGS:
- **IPCA** (SGS 1737, base dez/1993 = 100) — default; families earning 1–40 min. wages.
- **INPC** (SGS 188) — lower-income (1–5 min. wages), weights food more heavily; better
  demographic fit for feira shoppers. Available as a filter/flag, not yet the default.
Deflation is base-invariant (a ratio of levels), so the choice of index moves the coarse
timing buckets only marginally. Official IBGE formula: `real = nominal × (índice_base /
índice_data)`.

### Market Timing
A judgment about the **commodity itself**, independent of any price a shopper pays:
where today's real wholesale price sits in its own deflated 12-month distribution.
Buckets: **época barata** (≤33rd percentile) / **preço normal** / **época cara**
(≥67th percentile). Null (shown as nothing) when Price History has <30 samples, when
no Price Index is available, or when the latest index month is >90 days stale.
Computed against a chosen Price Index (default IPCA); always expressed "em reais de
hoje (<índice>, base <mês>)".

### Markup
A judgment about the **seller**: the ratio of what the shopper paid to the Reference
Price, on the same day. Buckets: **barato** (<1.7×) / **na média** (1.7–2.5×) /
**caro** (>2.5×). The bands are the retail feira margin over atacado — provisional,
not yet validated against real feira data.

### Fair Price Verdict
The composed judgment for a shopper: fuses **Markup** (is the seller fair?) and
**Market Timing** (is the commodity cheap now?) into one synthesized message. The two
axes can disagree — e.g. a fair Markup on an **época cara** commodity, or a **caro**
Markup on an **época barata** one — and the synthesis names that combination. Falls
back to Markup-only when Market Timing is null.

### Deflation base month
The most recent IPCA month available. Bulletins newer than it are treated at that
month's index (factor 1.0). All "real terms" values are labelled with this month so
the app never implies more precision than it has.
