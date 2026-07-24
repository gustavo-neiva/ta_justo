require "fileutils"
require "pathname"

module CeasaRio
  # Persists raw bulletin PDFs to disk so the source of every ingested price
  # can always be retraced. The archived PDF is the single source of truth:
  # jobs write it BEFORE ingesting, and Loader re-parses from it — so a
  # Bulletin can never exist without its source PDF on disk.
  module Archiver
    DEFAULT_RAW_DIR = "storage/ceasa/raw"

    class << self
      # On-disk archive root. Defaults to Rails.root/storage/ceasa/raw.
      # Settable (raw_dir=) so tests can point at an isolated temp dir.
      attr_writer :raw_dir

      def raw_dir
        @raw_dir || Rails.root.join(DEFAULT_RAW_DIR)
      end

      def archive_path(date)
        Pathname.new(raw_dir).join("#{date.strftime("%Y-%m-%d")}.pdf")
      end

      def archived?(date)
        File.exist?(archive_path(date))
      end

      # Writes the PDF bytes for `date` unless one is already archived
      # (idempotent — never clobbers an existing good archive).
      # Returns the path of the archived file.
      def write(body, date)
        FileUtils.mkdir_p(raw_dir)
        path = archive_path(date)
        File.binwrite(path, body) unless File.exist?(path)
        path
      end

      def reset! # for tests: fall back to the default root
        @raw_dir = nil
      end
    end
  end
end
