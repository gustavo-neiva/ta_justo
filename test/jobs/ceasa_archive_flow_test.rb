require "test_helper"
require "fileutils"

# Archival is guaranteed before ingest, tempfiles don't leak, Archiver is
# idempotent. Uses real fixtures (pdftotext is exercised) and the REAL archive
# path with explicit cleanup of the test date's file.
class CeasaArchiveFlowTest < ActiveSupport::TestCase
  MODERN = Rails.root.join("test/fixtures/files/ceasa/modern/2026-06-19.pdf").to_s
  PRICE_DATE = Date.new(2026, 6, 19)

  setup do
    # Isolated temp dir per test — never touches the real archive, and no
    # collision between parallel test processes (each gets its own dir).
    @tmp = Dir.mktmpdir("ceasa-archive-test")
    CeasaRio::Archiver.raw_dir = File.join(@tmp, "raw")
  end

  teardown do
    CeasaRio::Archiver.reset!
    FileUtils.rm_rf(@tmp) if @tmp
  end

  test "Archiver.write is idempotent and never clobbers an existing archive" do
    body_a = File.binread(MODERN)
    path = CeasaRio::Archiver.write(body_a, PRICE_DATE)
    assert CeasaRio::Archiver.archived?(PRICE_DATE)
    assert_equal path, CeasaRio::Archiver.archive_path(PRICE_DATE)

    # Second write with different bytes must NOT overwrite the good archive
    CeasaRio::Archiver.write("DIFFERENT-BYTES", PRICE_DATE)
    assert_equal body_a.bytesize, File.binread(path).bytesize
  end

  test "Loader#ingest_path parses from the archived file and persists a bulletin" do
    path = CeasaRio::Archiver.write(File.binread(MODERN), PRICE_DATE)
    assert_difference -> { Bulletin.where(price_date: PRICE_DATE).count } => 1 do
      CeasaRio::Loader.new.ingest_path(path, source_url: "https://example/test.pdf")
    end
    assert_equal "https://example/test.pdf", Bulletin.find_by(price_date: PRICE_DATE).source_url
  end

  test "Loader#ingest_path is idempotent" do
    path = CeasaRio::Archiver.write(File.binread(MODERN), PRICE_DATE)
    loader = CeasaRio::Loader.new
    loader.ingest_path(path, source_url: "https://example/test.pdf")
    assert_no_difference -> { Bulletin.where(price_date: PRICE_DATE).count } do
      loader.ingest_path(path, source_url: "https://example/test.pdf")
    end
  end

  test "FetchCeasaRioJob archives before ingest — PDF on disk when a Bulletin exists" do
    body = File.binread(MODERN)
    replace_new(CeasaRio::Fetcher, stub_methods(latest: [ PRICE_DATE, body ], url_for: "https://example/job.pdf"))

    FetchCeasaRioJob.new.perform

    assert Bulletin.exists?(price_date: PRICE_DATE), "bulletin created"
    assert CeasaRio::Archiver.archived?(PRICE_DATE), "PDF must be on disk for the bulletin"
    assert_equal body, File.binread(CeasaRio::Archiver.archive_path(PRICE_DATE))
  ensure
    restore_new(CeasaRio::Fetcher)
  end

  test "BackfillCeasaRioJob archives the fetched PDF and leaks no tempfiles" do
    body = File.binread(MODERN)
    url = "https://example/backfill.pdf"
    replace_new(CeasaRio::Crawler, stub_methods(discover_urls: [ url ]))
    replace_new(CeasaRio::Fetcher, stub_methods(fetch_and_validate: body, url_for: url))

    tmp_before = Dir.glob(File.join(Dir.tmpdir, "ceasa*.pdf")).sort
    BackfillCeasaRioJob.new.perform
    tmp_after = Dir.glob(File.join(Dir.tmpdir, "ceasa*.pdf")).sort

    assert CeasaRio::Archiver.archived?(PRICE_DATE), "backfilled PDF archived"
    assert_equal tmp_before, tmp_after, "no new tempfiles leaked"
  ensure
    restore_new(CeasaRio::Crawler)
    restore_new(CeasaRio::Fetcher)
  end

  private

  def stub_methods(methods)
    o = Object.new
    methods.each { |k, v| o.define_singleton_method(k) { |*| v } }
    o
  end

  def replace_new(klass, instance)
    @orig_new ||= {}
    @orig_new[klass] = klass.method(:new)
    klass.define_singleton_method(:new) { instance }
  end

  def restore_new(klass)
    return unless @orig_new&.key?(klass)
    klass.define_singleton_method(:new, @orig_new[klass])
    @orig_new.delete(klass)
  end
end
