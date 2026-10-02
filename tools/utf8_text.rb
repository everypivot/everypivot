# frozen_string_literal: true

module EveryPivot
  # Declared repository text is UTF-8, independent of the process locale.
  # Byte-sensitive inputs (archives, source snapshots and digests) stay binary.
  module Utf8Text
    class Error < StandardError; end

    def self.read(path)
      decode(File.binread(path), path: path)
    end

    def self.decode(bytes, path:)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      unless text.valid_encoding?
        raise Error, "Invalid UTF-8 in #{path.to_s.inspect}"
      end
      if text.start_with?("\uFEFF")
        raise Error, "UTF-8 BOM is not permitted in #{path.to_s.inspect}"
      end

      text
    end
  end
end
