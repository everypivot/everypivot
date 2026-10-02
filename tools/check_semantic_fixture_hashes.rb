#!/usr/bin/env ruby
# frozen_string_literal: true

# Read-only reproduction of the explicitly reviewed synthetic hash derivations.
# This does not authorize new fixture bytes, regenerate a pin, execute a native
# analysis tool, prove source authenticity, or adopt scanner output as evidence.
require 'base64'
require 'openssl'
require_relative 'check_cti_promotion_lint'

module EveryPivot
  module SemanticFixtureHashReview
    ROOT = File.expand_path('..', __dir__)
    HEX = /\b(?:[a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64})\b/i
    module_function

    # Independent implementation of the published canonical_json_v1 recipe;
    # deliberately does not call the semantic evaluator or fixture factories.
    def canonical(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, out| out[key] = canonical(value[key]) }
      when Array
        value.map { |item| canonical(item) }
      else
        value
      end
    end

    def canonical_digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end

    def file_path(root, relative)
      raise 'Review recipe path must be repository-relative' unless relative.is_a?(String) && !Pathname(relative).absolute?
      path = File.expand_path(relative, root)
      raise 'Review recipe path escapes repository' unless path.start_with?(File.expand_path(root) + File::SEPARATOR)
      path
    end

    def read_json(root, relative)
      path = file_path(root, relative)
      JSON.parse(Utf8Text.read(path))
    end

    def reproduce(recipe, root: ROOT)
      case recipe.fetch('recipe')
      when 'file_bytes_sha256'
        Digest::SHA256.file(file_path(root, recipe.fetch('file'))).hexdigest
      when 'preserved_string_sha256'
        bytes = read_json(root, recipe.fetch('file')).fetch(recipe.fetch('container')).fetch(recipe.fetch('source_id'))
        Digest::SHA256.hexdigest(bytes)
      when 'record_canonical_json_v1_sha256'
        data = read_json(root, recipe.fetch('file'))
        records = (data['evidence'] || data).fetch('records')
        matches = records.select { |record| record['id'] == recipe.fetch('record_id') }
        raise 'Review recipe record must resolve uniquely' unless matches.length == 1
        canonical_digest(matches.first)
      when 'canonical_json_v1_sha256'
        canonical_digest(read_json(root, recipe.fetch('file')))
      when 'finding_claim_key_v1'
        data = read_json(root, recipe.fetch('file'))
        claim = data.fetch('claims').fetch(recipe.fetch('claim_index'))
        canonical_digest('qualification' => [data.fetch('pattern').downcase, '1.0'], 'identity' => claim.fetch('identity'))
      when 'base64_bytes_sha256'
        vector = read_json(root, recipe.fetch('file')).fetch('certificates').fetch(recipe.fetch('vector_index'))
        certificate = OpenSSL::X509::Certificate.new(vector.fetch('pem'))
        raise 'PEM/DER synthetic vector disagreement' unless certificate.to_der == Base64.strict_decode64(vector.fetch('der_base64'))
        raise 'Certificate/public-key synthetic vector disagreement' unless certificate.public_key.to_der == Base64.strict_decode64(vector.fetch('spki_der_base64'))
        raise 'Unexpected certificate vector field' unless %w[der_base64 spki_der_base64].include?(recipe.fetch('field'))
        Digest::SHA256.hexdigest(Base64.strict_decode64(vector.fetch(recipe.fetch('field'))))
      when 'synthetic_literal_sha256'
        # These prose preimages are documented factory inputs, not fetched files.
        Digest::SHA256.hexdigest(recipe.fetch('input'))
      when 'synthetic_signing_label_sha256'
        # Label-only values exercise typed identity; no signature/PE/APK digest
        # or cryptographic verification is claimed by this synthetic recipe.
        Digest::SHA256.hexdigest(recipe.fetch('parts').join)
      when 'explicit_synthetic_selector_vector'
        value = recipe.fetch('value')
        raise 'Unexpected artificial selector vector' unless value == '0123456789abcdef' * 2
        value
      else
        raise "Unknown reviewed derivation recipe: #{recipe['recipe']}"
      end
    end

    def check(root: ROOT)
      bytes = CtiPromotionLint::SEMANTIC_FIXTURE_REVIEW_PATH.binread
      raise 'Review manifest pin mismatch' unless Digest::SHA256.hexdigest(bytes) == CtiPromotionLint::SEMANTIC_FIXTURE_REVIEW_SHA256
      review = JSON.parse(Utf8Text.decode(bytes, path: CtiPromotionLint::SEMANTIC_FIXTURE_REVIEW_PATH))
      actual = Dir[File.join(root, 'fixtures/semantic-families/**/*.json')].map { |path| Pathname(path).relative_path_from(Pathname(root)).to_s }.sort
      raise 'Semantic JSON inventory differs from reviewed scope' unless actual == review.fetch('inventory').keys.sort
      review.fetch('inventory').each do |path, expected|
        raise "Reviewed bytes changed: #{path}" unless Digest::SHA256.file(file_path(root, path)).hexdigest == expected
      end
      review.fetch('derivations').each do |value, recipe|
        raise "Unreproduced reviewed value: #{value}" unless reproduce(recipe, root: root) == value
      end
      covered = []
      actual.each do |path|
        hashes = File.binread(file_path(root, path)).scan(HEX).uniq.reject { |value| CtiPromotionLint.placeholder_hex?(value) }.sort
        entry = review.fetch('files')[path]
        if hashes.empty?
          raise "Unnecessary hash exception: #{path}" if entry
          next
        end
        raise "Missing or excessive hash exception: #{path}" unless entry && hashes == entry.fetch('allowed_hex').sort
        raise "Fixture/manifest byte pin disagreement: #{path}" unless entry.fetch('file_sha256') == review.fetch('inventory').fetch(path)
        raise "Unexplained hash: #{path}" unless (hashes - review.fetch('derivations').keys).empty?
        covered.concat(hashes)
      end
      raise 'Unused reviewed derivations' unless covered.uniq.sort == review.fetch('derivations').keys.sort
      {'json_files' => actual.length, 'exception_files' => review.fetch('files').length, 'unique_values' => covered.uniq.length,
       'derivation_counts' => review.fetch('derivations').values.group_by { |recipe| recipe.fetch('recipe') }.transform_values(&:length),
       'review_manifest_sha256' => Digest::SHA256.hexdigest(bytes)}
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    puts JSON.pretty_generate(EveryPivot::SemanticFixtureHashReview.check)
  rescue StandardError => e
    warn "Semantic fixture hash review failed: #{e.message}"
    exit 1
  end
end
