# Chart Refinement Plan — `d3_line_chart_controller.js`

All changes are in **one file** unless noted:
`app/javascript/controllers/d3_line_chart_controller.js`

There are **three independent fixes**. Do them in order. After each fix,
reload the product page chart in the browser and visually confirm before
moving on. Do NOT change anything outside the lines named below.

---

## FIX 1 — Stop the double draw / line-drawn-twice flicker (HIGH PRIORITY)

### Why
Stimulus calls every `xxxValueChanged()` callback **once during
initialization, before `connect()` runs**. Each of those callbacks calls
`this.draw()`, and `connect()` calls `this.draw()` again. So the line-draw
animation runs multiple times on load → the flicker.

### What to change

**1a. Add a guard flag in `connect()`** (currently lines 20–25):

```js
  connect() {
    this._debouncedDraw = this._debounce(() => this.draw(), 300)
    this.resizeObserver = new ResizeObserver(this._debouncedDraw)
    this.resizeObserver.observe(this.chartTarget)
    this._connected = true   // <-- ADD THIS LINE (before the draw call)
    this.draw()
  }
```

**1b. Guard every `*ValueChanged` callback** so they are no-ops until the
controller is connected. Replace the block currently at lines 43–48:

```js
  showUsdValueChanged() { this.draw() }
  showSma7ValueChanged() { this.draw() }
  showSma30ValueChanged() { this.draw() }
  showSeasonalValueChanged() { this.draw() }
  toggleSeasonal(event) { this.showSeasonalValue = event.target.checked }
```

with:

```js
  showUsdValueChanged() { if (this._connected) this.draw() }
  showSma7ValueChanged() { if (this._connected) this.draw() }
  showSma30ValueChanged() { if (this._connected) this.draw() }
  showSeasonalValueChanged() { if (this._connected) this.draw() }
  toggleSeasonal(event) { this.showSeasonalValue = event.target.checked }
```

### Result
On load, the init-time `*ValueChanged` callbacks do nothing (flag not set
yet), and `connect()` does exactly **one** `draw()`. User toggles
(checkbox) still work because by then `_connected === true`.

### Verify
Reload the page. The green line should animate **once**, no flicker.

---

## FIX 2 — Stop the line/area from crossing (overflowing) the axes

### Why
The line path (lines 223–230) has a `drop-shadow` filter and a 2px stroke.
The first and last points sit exactly at `x=0` and `x=innerWidth`, so the
stroke + shadow bleed over the Y-axis (left) and below the X-axis (bottom).
Nothing clips drawing to the plot rectangle.

### What to change — add a clip-path and apply it to the plotted paths

**2a.** Right after the gradient `<defs>` is created (the `const defs =
svg.append("defs")` at line 184), add a clipPath. Insert these lines
immediately after that `defs` declaration:

```js
    // Clip plotted series to the inner plot rect so the line/area + its
    // drop-shadow never render over the axes.
    const clipId = `plot-clip-${Math.random().toString(36).slice(2, 8)}`
    defs.append("clipPath")
      .attr("id", clipId)
      .append("rect")
      .attr("x", 0)
      .attr("y", 0)
      // pad top by a few px so the drop-shadow above the highest point
      // is not hard-cut; bottom/left/right are clipped flush to the axes.
      .attr("width", innerWidth)
      .attr("height", innerHeight)
```

**2b.** Wrap the data series in a clipped group. The cleanest approach:
create one group that holds the area + price line + overlays, and give it
the clip. Find the **area path** append (lines 210–213):

```js
    g.append("path")
      .datum(data)
      .attr("fill", `url(#${gradientId})`)
      .attr("d", area)
```

Change `g.append` here, and on the **price line path** (line 223), the
**USD line** (line 256), the **SMA lines** (`drawSmaLine`, line 290), and
the **seasonal line** (line 316) to append into a clipped sub-group
instead of `g`.

Concretely, **before the area path append (line 210)** add:

```js
    // All data series go in here so they share the axis clip-path.
    const series = g.append("g").attr("clip-path", `url(#${clipId})`)
```

Then replace `g.append("path")` with `series.append("path")` in these
five spots ONLY:
- area fill (line 210)
- price line (line 223: `const linePath = g.append("path")` -> `series.append("path")`)
- USD line (line 256, inside `if (this.showUsdValue)`)
- SMA line (line 290, inside `drawSmaLine`)
- seasonal line (line 316, inside the seasonal `if`)

Do **NOT** change the axis groups, grid lines, crosshair, or tooltip —
those must stay on `g`/`svg`.

### Note / gotcha
The drop-shadow on the price line (line 230) will now be clipped at the
plot edges. That is the desired behavior ("don't cross the axis"). If the
clipped shadow at the very top looks abrupt, change the clip rect to
`-6` y and `innerHeight + 6` height to give 6px of breathing room at top
only — but keep left/right/bottom flush.

### Verify
Reload. The green line and shaded area must stay strictly inside the plot
box; no green pixels on top of the left Y-axis or below the bottom X-axis.

---

## FIX 3 — Smoothing the line (DECIDED: Option A, window = 5)

User decision: show **trends, not vibrations**. Tooltips keep **real raw
data**. The visual line is smoothed with a **5-point centered moving
average** (Option A below). Do NOT use Option B — it is kept only as a
rejected alternative for reference. Use `window = 5` (not 3).

The data is stair-stepped (flat plateaus + single-day jumps). It already
uses `curveMonotoneX` (line 200) which avoids overshoot.

### Option A (CHOSEN, non-destructive): moving-average smoothing
Smooth the *price* series with a centered moving average before
drawing, so plateaus round off without inventing big swings. The crosshair
tooltip keeps showing RAW prices (it already uses `validData`, which
you will keep raw).

Add a helper near `_formatBrlNumber` (around line 56) :

```js
  // Centered moving average over `window` points (odd number). Keeps nulls
  // (gap sentinels) as nulls so the line still breaks at gaps.
  _smooth(points, window = 3) {
    if (window < 2) return points
    const half = Math.floor(window / 2)
    return points.map((p, i) => {
      if (p.price == null) return p
      let sum = 0, n = 0
      for (let j = i - half; j <= i + half; j++) {
        const q = points[j]
        if (q && q.price != null) { sum += q.price; n++ }
      }
      return { ...p, price: sum / n }
    })
  }
```

Then, where the line/area are drawn, build a smoothed copy for the VISUAL
path but keep `validData` raw for the crosshair. After `const data = []`
block (ends ~line 145), add:

```js
    const smoothData = this._smooth(data, 5)  // 5-point centered average — trends, not vibrations
```

and in the **area** (`.datum(data)`, line 211) and **price line**
(`.datum(data)`, line 224) replace `data` with `smoothData`.
Leave `validData` (line 159) and the crosshair (line 395) on RAW data so
tooltips show real CEASA prices.

Use `window = 5`. If the user later wants even smoother, try `7`, but do not
exceed 7 (it erases real seasonal moves). The seasonal overlay line is
already a monthly median and must NOT be smoothed.

### Option B (REJECTED — kept for reference only, do NOT implement)
Swap `curveMonotoneX` for `d3.curveCatmullRom.alpha(0.5)` ONLY for the
price line. At line 199–202:

```js
    const curveFactory = this.curveTypeValue === "curveMonotoneX"
      ? d3.curveMonotoneX
      : d3.curveLinear
```

This is shared by area + line. To smooth ONLY the line, give the line its
own curve at line 220 (`.curve(curveFactory)`):

```js
      .curve(d3.curveCatmullRom.alpha(0.5))
```

Catmull-Rom **overshoots** on sharp spikes (can dip below the lowest point
/ above the highest), which combined with FIX 2's clip is acceptable but
may look like values that don't exist. Prefer Option A if accuracy matters.

### Verify
Reload. Line should look visibly smoother and show trends, not daily
vibrations; hover tooltip values must still match the real CEASA prices
(Option A guarantees this, since the crosshair stays on raw `validData`).

---

## Decisions locked (from user)
- Smoothing: **Option A**, moving average, **window = 5**.
- Animation: **keep it, fire exactly once** on load (that is what FIX 1 achieves).
- Tooltips: **real raw data** (crosshair stays on `validData`).
- Goal: lines show **trends**, not daily vibrations.

## Ordering & testing checklist
1. Implement FIX 1, reload, confirm single animation (no flicker).
2. Implement FIX 2, reload, confirm no overflow past axes.
3. Implement FIX 3 (chosen option), reload, confirm smoother + accurate tooltip.
4. Toggle the "Mostrar sazonalidade" checkbox — it must still redraw and the
   line must NOT re-animate flicker (FIX 1 only stops the DOUBLE draw on load;
   a single redraw on toggle is expected and fine).
5. Resize the window — debounced redraw (line 21) should still work.

## Files referenced
- `app/javascript/controllers/d3_line_chart_controller.js` — all edits
- `app/views/products/_chart.html.erb` — wiring (no edits needed)
- `app/assets/stylesheets/components/chart.css` — styles (no edits needed)
