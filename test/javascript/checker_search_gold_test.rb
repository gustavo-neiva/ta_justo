require "test_helper"
require "open3"

# Runs the real client-side scorer (app/javascript/lib/checker_search.js) in
# Node against the shopper gold set. Top-3 hit rate must stay ≥ 90% per set.
class CheckerSearchGoldTest < ActiveSupport::TestCase
  GOLD = Rails.root.join("test/fixtures/files/checker_search_gold.json")
  RUNNER = Rails.root.join("test/javascript/checker_search_gold.mjs")

  test "top-3 hit rate ≥ 90% on every gold set" do
    skip "node not installed" unless system("node", "--version", out: File::NULL, err: File::NULL)

    rows = Tempfile.create([ "checker_index", ".json" ]) do |f|
      f.write(CheckerCatalog.search_index.to_json)
      f.flush
      out, err, status = Open3.capture3("node", RUNNER.to_s, f.path, GOLD.to_s)
      assert status.success?, err
      out.lines.map { |l| JSON.parse(l) }
    end

    rows.group_by { |r| r["set"] }.each do |set, results|
      misses = results.reject { |r| r["hit"] }
      rate = 100.0 * (results.size - misses.size) / results.size
      assert rate >= 90, "#{set}: top-3 #{rate.round}% — misses: " +
        misses.map { |m| "#{m["q"]} → #{m["expected"]} (got #{m["top3"].join(", ")})" }.join("; ")
    end
  end
end
