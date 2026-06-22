import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Array,
    unit: String,
    showUsd: { type: Boolean, default: false },
    showSma7: { type: Boolean, default: false },
    showSma30: { type: Boolean, default: false },
    sma7: { type: Array, default: [] },
    sma30: { type: Array, default: [] },
    seasonal: { type: Array, default: [] },
    showSeasonal: { type: Boolean, default: true },
    height: { type: Number, default: 400 },
    curveType: { type: String, default: "curveLinear" }
  }

  connect() {
    this._debouncedDraw = this._debounce(() => this.draw(), 300)
    this._resizeObserverReady = false
    this.resizeObserver = new ResizeObserver(() => {
      if (!this._resizeObserverReady) {
        this._resizeObserverReady = true
        return // skip the initial async callback that fires right after observe()
      }
      this._debouncedDraw()
    })
    this.resizeObserver.observe(this.chartTarget)
    this._connected = true
    this.draw()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  toggleUsd(event) {
    this.showUsdValue = event.target.checked
  }

  toggleSma7(event) {
    this.showSma7Value = event.target.checked
  }

  toggleSma30(event) {
    this.showSma30Value = event.target.checked
  }

  showUsdValueChanged() { if (this._connected) this.draw() }
  showSma7ValueChanged() { if (this._connected) this.draw() }
  showSma30ValueChanged() { if (this._connected) this.draw() }
  showSeasonalValueChanged() { if (this._connected) this.draw() }
  toggleSeasonal(event) { this.showSeasonalValue = event.target.checked }

  // Debounce utility: delays fn execution until after `delay` ms of inactivity
  _debounce(fn, delay) {
    let timer
    const debounced = (...args) => {
      clearTimeout(timer)
      timer = setTimeout(() => fn.apply(this, args), delay)
    }
    debounced.cancel = () => clearTimeout(timer)
    return debounced
  }

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

  // Brazilian number formatter: 1234.56 -> "1.234,56"
  _formatBrlNumber(value) {
    if (value == null) return "—"
    const rounded = value.toFixed(2)
    const [integer, decimal] = rounded.split(".")
    // Add thousands separator (dot) before each group of 3 digits from right
    const withSeparator = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
    return `${withSeparator},${decimal}`
  }

  draw() {
    if (!this.dataValue.length) return

    const container = this.chartTarget
    const rect = container.getBoundingClientRect()
    const width = rect.width
    const height = this.heightValue

    // Clear previous
    d3.select(container).select("svg").remove()

    const margin = { top: 20, right: this.showUsdValue ? 60 : 20, bottom: 50, left: 65 }
    const innerWidth = width - margin.left - margin.right
    const innerHeight = height - margin.top - margin.bottom

    if (innerWidth <= 0 || innerHeight <= 0) return

    // Read design tokens
    const style = getComputedStyle(document.documentElement)
    const colorPrimary = style.getPropertyValue("--color-primary-light").trim() || "#2e7d32"
    const colorSuccess = style.getPropertyValue("--color-success").trim() || "#2e7d32"
    const colorGray400 = style.getPropertyValue("--color-gray-400").trim() || "#9ca3af"
    const colorBorder = style.getPropertyValue("--color-border").trim() || "#e0e0e0"

    const svg = d3.select(container).append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("role", "img")
      .attr("aria-label", `Gráfico de preços - ${this.unitValue}`)

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Parse data - use UTC to avoid timezone shifts
    const parsed = this.dataValue
      .map(d => ({
        date: new Date(`${d.date}T12:00:00Z`),
        price: d.price,
        usd: d.usd
      }))
      .filter(d => d.price != null && d.price > 0)

    // Spike removal: detect "zigzag" points where price spikes away from both neighbors
    // e.g. 42→65→42: the 65 is a spike because both neighbors agree at ~42
    const SPIKE_THRESHOLD = 0.25 // 25% deviation from neighbor average
    const despike = (pts) => {
      if (pts.length < 3) return pts
      const keep = [true]
      for (let i = 1; i < pts.length - 1; i++) {
        const prev = pts[i - 1].price
        const curr = pts[i].price
        const next = pts[i + 1].price
        const neighborAvg = (prev + next) / 2
        // Spike: current deviates >threshold from neighbor average, AND neighbors are close to each other
        const devFromAvg = Math.abs(curr - neighborAvg) / neighborAvg
        const neighborSpread = Math.abs(prev - next) / Math.max(prev, next)
        keep.push(!(devFromAvg > SPIKE_THRESHOLD && neighborSpread < 0.15))
      }
      keep.push(true)
      return pts.filter((_, i) => keep[i])
    }
    const rawData = despike(parsed)

    // Gap detection: insert null-price sentinels at large date gaps
    // to prevent D3 from drawing connecting lines across missing periods
    const data = []
    if (rawData.length >= 2) {
      const intervals = []
      for (let i = 1; i < rawData.length; i++) {
        intervals.push(rawData[i].date - rawData[i - 1].date)
      }
      intervals.sort((a, b) => a - b)
      const medianInterval = intervals[Math.floor(intervals.length / 2)]
      const gapThreshold = Math.max(medianInterval * 4, 14 * 24 * 60 * 60 * 1000) // min 14 days

      data.push(rawData[0])
      for (let i = 1; i < rawData.length; i++) {
        const gap = rawData[i].date - rawData[i - 1].date
        if (gap > gapThreshold) {
          data.push({ date: new Date(rawData[i - 1].date.getTime() + 1), price: null, usd: null, _gap: true })
        }
        data.push(rawData[i])
      }
    } else {
      data.push(...rawData)
    }

    const smoothData = this._smooth(data, 5)  // 5-point centered average — trends, not vibrations

    // Scales
    const xScale = d3.scaleTime()
      .domain(d3.extent(data, d => d.date))
      .range([0, innerWidth])

    const validData = data.filter(d => d.price != null)
    const yScale = d3.scaleLinear()
      .domain([
        d3.min(validData, d => d.price) * 0.98,
        d3.max(validData, d => d.price) * 1.02
      ])
      .range([innerHeight, 0])
      .nice()

    // Grid lines
    g.append("g")
      .attr("class", "grid-lines")
      .selectAll("line")
      .data(yScale.ticks(5))
      .join("line")
      .attr("x1", 0)
      .attr("x2", innerWidth)
      .attr("y1", d => yScale(d))
      .attr("y2", d => yScale(d))
      .attr("stroke", colorBorder)
      .attr("stroke-dasharray", "2,3")

    // Gradient fill
    const gradientId = `area-gradient-${Math.random().toString(36).slice(2, 8)}`
    const defs = svg.append("defs")
    const clipId = `plot-clip-${Math.random().toString(36).slice(2, 8)}`
    defs.append("clipPath")
      .attr("id", clipId)
      .append("rect")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", innerWidth)
      .attr("height", innerHeight)
    const gradient = defs.append("linearGradient")
      .attr("id", gradientId)
      .attr("x1", "0%").attr("y1", "0%")
      .attr("x2", "0%").attr("y2", "100%")
    gradient.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", colorSuccess)
      .attr("stop-opacity", 0.15)
    gradient.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", colorSuccess)
      .attr("stop-opacity", 0.01)

    // Dynamic curve type based on data quality
    const curveFactory = this.curveTypeValue === "curveMonotoneX"
      ? d3.curveMonotoneX
      : d3.curveLinear

    // Area - use defined() to lift pen at gap sentinels
    const area = d3.area()
      .defined(d => d.price != null)
      .x(d => xScale(d.date))
      .y0(innerHeight)
      .y1(d => yScale(d.price))
      .curve(curveFactory)

    // All data series go in here so they share the axis clip-path.
    const series = g.append("g").attr("clip-path", `url(#${clipId})`)

    series.append("path")
      .datum(smoothData)
      .attr("fill", `url(#${gradientId})`)
      .attr("d", area)

    // Main price line - use defined() to break line at gaps
    const line = d3.line()
      .defined(d => d.price != null)
      .x(d => xScale(d.date))
      .y(d => yScale(d.price))
      .curve(curveFactory)

    const linePath = series.append("path")
      .datum(smoothData)
      .attr("fill", "none")
      .attr("stroke", colorPrimary)
      .attr("stroke-width", 2)
      .attr("d", line)
      .style("filter", "drop-shadow(0 2px 4px rgba(46, 125, 50, 0.3))")

    // Animate line drawing
    const totalLength = linePath.node().getTotalLength()
    linePath
      .attr("stroke-dasharray", `${totalLength} ${totalLength}`)
      .attr("stroke-dashoffset", totalLength)
      .transition()
      .duration(800)
      .ease(d3.easeCubicOut)
      .attr("stroke-dashoffset", 0)

    // USD line (dashed, secondary axis)
    if (this.showUsdValue) {
      const usdData = data.filter(d => d.usd != null)
      if (usdData.length > 1) {
        const yScaleUsd = d3.scaleLinear()
          .domain([
            d3.min(usdData, d => d.usd) * 0.98,
            d3.max(usdData, d => d.usd) * 1.02
          ])
          .range([innerHeight, 0])
          .nice()

        const usdLine = d3.line()
          .x(d => xScale(d.date))
          .y(d => yScaleUsd(d.usd))
          .curve(d3.curveLinear)

        series.append("path")
          .datum(usdData)
          .attr("fill", "none")
          .attr("stroke", "#1a73e8")
          .attr("stroke-width", 1.5)
          .attr("stroke-dasharray", "6,3")
          .attr("d", usdLine)

        // Right axis for USD
        g.append("g")
          .attr("transform", `translate(${innerWidth},0)`)
          .call(d3.axisRight(yScaleUsd).ticks(5).tickFormat(d => `US$ ${this._formatBrlNumber(d)}`))
          .call(g => g.select(".domain").attr("stroke", "#1a73e8").attr("stroke-opacity", 0.3))
          .call(g => g.selectAll(".tick text").attr("fill", "#1a73e8").style("font-size", "10px"))
          .call(g => g.selectAll(".tick line").attr("stroke", "#1a73e8").attr("stroke-opacity", 0.3))

        this._yScaleUsd = yScaleUsd
      }
    }

    // SMA overlay lines
    const drawSmaLine = (smaData, color, dashArray) => {
      if (!smaData || smaData.length < 2) return
      const parsed = smaData.map(d => ({
        date: new Date(`${d.date}T12:00:00Z`),
        value: d.value
      }))
      const smaLine = d3.line()
        .x(d => xScale(d.date))
        .y(d => yScale(d.value))
        .curve(d3.curveLinear)

      series.append("path")
        .datum(parsed)
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", 1.5)
        .attr("stroke-dasharray", dashArray)
        .attr("opacity", 0.7)
        .attr("d", smaLine)
    }

    if (this.showSma7Value) {
      drawSmaLine(this.sma7Value, "#ff9800", "6,3")
    }
    if (this.showSma30Value) {
      drawSmaLine(this.sma30Value, "#9c27b0", "3,3")
    }

    // Seasonality overlay: typical (median) price per calendar month.
    if (this.showSeasonalValue && this.seasonalValue.length > 1) {
      const seasonal = this.seasonalValue
        .map(d => ({ date: new Date(`${d.date}T12:00:00Z`), value: d.price }))
        .filter(d => d.value != null)
      const seasonalLine = d3.line()
        .x(d => xScale(d.date))
        .y(d => yScale(d.value))
        .curve(d3.curveMonotoneX)
      series.append("path")
        .datum(seasonal)
        .attr("fill", "none")
        .attr("stroke", "#b8860b")          // gold — distinct from green price line
        .attr("stroke-width", 2)
        .attr("stroke-dasharray", "8,4")
        .attr("opacity", 0.85)
        .attr("d", seasonalLine)
    }

    // Axes - Reactive X-axis based on date range
    const [minDate, maxDate] = d3.extent(data, d => d.date)
    const daySpan = Math.ceil((maxDate - minDate) / (1000 * 60 * 60 * 24))

    // Determine tick values and format based on date range
    let tickCount, showYearOnFirst
    if (daySpan > 180) {
      // Long range (1A, Máx): fewer ticks, always show year
      tickCount = innerWidth < 400 ? 4 : 6
      showYearOnFirst = true
    } else {
      // Short/Medium range (7D, 30D, 90D): more ticks
      tickCount = innerWidth < 400 ? 5 : 8
      showYearOnFirst = daySpan > 60
    }

    // Generate explicit tick values
    const tickStep = Math.max(1, Math.floor(data.length / tickCount))
    const tickDates = []
    for (let i = 0; i < data.length; i += tickStep) {
      tickDates.push(data[i].date)
    }
    // Ensure the last date is included
    if (tickDates[tickDates.length - 1] !== data[data.length - 1].date) {
      tickDates.push(data[data.length - 1].date)
    }

    // Check for year transitions
    const minYear = minDate.getFullYear()
    const maxYear = maxDate.getFullYear()
    const crossesYear = minYear !== maxYear

    // Format function with explicit tick dates
    const formatTickDate = (date) => {
      const day = String(date.getDate()).padStart(2, "0")
      const month = String(date.getMonth() + 1).padStart(2, "0")
      const year = date.getFullYear()
      const yearShort = String(year).slice(-2)

      // Always show year for long ranges
      if (daySpan > 180) {
        return `${day}/${month}/'${yearShort}`
      }

      // For shorter ranges, show year on first tick (if range > 60 days) or year transitions
      const tickIndex = tickDates.indexOf(date)
      const isFirst = tickIndex === 0
      const prevYear = tickIndex > 0 ? tickDates[tickIndex - 1].getFullYear() : null
      const isYearChange = prevYear !== null && prevYear !== year

      if (isYearChange || (isFirst && showYearOnFirst)) {
        return `${day}/${month}/'${yearShort}`
      }
      return `${day}/${month}`
    }

    g.append("g")
      .attr("transform", `translate(0,${innerHeight})`)
      .call(d3.axisBottom(xScale).tickValues(tickDates).tickFormat(formatTickDate))
      .call(g => g.select(".domain").attr("stroke", colorBorder))
      .call(g => g.selectAll(".tick text")
        .attr("fill", colorGray400)
        .style("font-size", "10px")
        .attr("text-anchor", "end")
        .attr("transform", "rotate(-35)")
        .attr("dx", "-0.4em")
        .attr("dy", "0.6em"))
      .call(g => g.selectAll(".tick line").attr("stroke", colorBorder))

    g.append("g")
      .call(d3.axisLeft(yScale).ticks(5).tickFormat(d => this._formatBrlNumber(d)))
      .call(g => g.select(".domain").attr("stroke", colorBorder))
      .call(g => g.selectAll(".tick text").attr("fill", colorGray400).style("font-size", "10px"))
      .call(g => g.selectAll(".tick line").attr("stroke", colorBorder))

    // Build a date→smoothed-price lookup so the crosshair dot tracks the visual line.
    const smoothPriceByDate = new Map(
      smoothData.filter(d => d.price != null).map(d => [d.date.getTime(), d.price])
    )

    // Interactive crosshair — use only valid (non-gap) data for bisect
    this._setupCrosshair(g, svg, validData, xScale, yScale, innerWidth, innerHeight, margin, d3, smoothPriceByDate)
  }

  _setupCrosshair(g, svg, data, xScale, yScale, innerWidth, innerHeight, margin, d3, smoothPriceByDate = new Map()) {
    const style = getComputedStyle(document.documentElement)
    const colorPrimary = style.getPropertyValue("--color-primary-light").trim() || "#2e7d32"

    // Crosshair elements
    const crosshairGroup = g.append("g").style("display", "none")

    crosshairGroup.append("line")
      .attr("class", "crosshair-v")
      .attr("y1", 0)
      .attr("y2", innerHeight)
      .attr("stroke", "#999")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "3,3")

    crosshairGroup.append("circle")
      .attr("class", "crosshair-dot")
      .attr("r", 5)
      .attr("fill", colorPrimary)
      .attr("stroke", "white")
      .attr("stroke-width", 2)

    // Tooltip
    const tooltip = d3.select(this.chartTarget).append("div")
      .attr("class", "d3-tooltip")
      .style("display", "none")

    // Overlay for mouse/touch events
    const bisect = d3.bisector(d => d.date).left

    const updateChart = (mouseX) => {
      const x0 = xScale.invert(mouseX)
      const i = bisect(data, x0, 1)
      const d0 = data[i - 1]
      const d1 = data[i]
      if (!d0) return
      const d = d1 && (x0 - d0.date > d1.date - x0) ? d1 : d0

      const cx = xScale(d.date)
      const smoothedPrice = smoothPriceByDate.get(d.date.getTime()) ?? d.price
      const cy = yScale(smoothedPrice)

      crosshairGroup.select(".crosshair-v")
        .attr("x1", cx).attr("x2", cx)

      crosshairGroup.select(".crosshair-dot")
        .attr("cx", cx).attr("cy", cy)

      const dateStr = `${String(d.date.getDate()).padStart(2, "0")}/${String(d.date.getMonth() + 1).padStart(2, "0")}/${d.date.getFullYear()}`
      let html = `<strong>${dateStr}</strong><br>R$ ${this._formatBrlNumber(d.price)}`
      if (d.usd != null) html += `<br>US$ ${this._formatBrlNumber(d.usd)}`

      tooltip.html(html).style("display", null)

      // Position tooltip
      const tooltipNode = tooltip.node()
      const tooltipWidth = tooltipNode.offsetWidth || 120
      const leftPos = cx + margin.left + 12
      const rightEdge = leftPos + tooltipWidth
      const containerWidth = this.chartTarget.offsetWidth

      tooltip
        .style("top", `${cy + margin.top - 10}px`)
        .style("left", rightEdge > containerWidth
          ? `${cx + margin.left - tooltipWidth - 12}px`
          : `${leftPos}px`)
    }

    g.append("rect")
      .attr("width", innerWidth)
      .attr("height", innerHeight)
      .attr("fill", "transparent")
      .on("mouseenter", () => {
        crosshairGroup.style("display", null)
        tooltip.style("display", null)
      })
      .on("mouseleave", () => {
        crosshairGroup.style("display", "none")
        tooltip.style("display", "none")
      })
      .on("mousemove", (event) => {
        const [mouseX] = d3.pointer(event)
        updateChart(mouseX)
      })
      // Touch support
      .on("touchstart", (event) => {
        event.preventDefault()
        crosshairGroup.style("display", null)
        const [touchX] = d3.pointer(event)
        updateChart(touchX)
      })
      .on("touchmove", (event) => {
        event.preventDefault()
        const [touchX] = d3.pointer(event)
        updateChart(touchX)
      })
      .on("touchend", () => {
        crosshairGroup.style("display", "none")
        tooltip.style("display", "none")
      })
  }
}
