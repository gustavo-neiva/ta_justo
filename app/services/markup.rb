# Markup — value object for the seller margin axis
#
# "Is this seller charging a fair margin?"
# Compares paid price vs CEASA wholesale — same-day, nominal (no deflation).
#
# From plan §2: Markup is the spine (always present); paid-dependent.
class Markup
  # ⚠️ PROVISIONAL bands — a GUESS, not yet validated against real feira data (§3.2).
  BARATO_MAX = 1.7  # < 1.7× atacado → :barato
  MEDIA_MAX  = 2.5  # 1.7–2.5× → :media ; > 2.5× → :caro

  attr_reader :ratio, :bucket

  def initialize(ratio:)
    @ratio  = ratio.to_f
    @bucket = classify(@ratio)
  end

  private

  def classify(ratio)
    ratio < BARATO_MAX ? :barato : (ratio <= MEDIA_MAX ? :media : :caro)
  end
end
