#!/usr/bin/env ruby
# frozen_string_literal: true

require 'base64'
require 'digest'
require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'rubygems/package'
require 'tmpdir'
require 'yaml'
require 'zlib'
require_relative 'utf8_text'

class Utf8TextTest < Minitest::Test
  ROOT = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: __FILE__)).join('..').expand_path
  TEXT = "ASCII café Ελληνικά 中文 العربية 😀 e\u0301".freeze
  INVALID = ["\xFF".b, "\xC0\xAF".b, "\xED\xA0\x80".b,
             "\xF4\x90\x80\x80".b, "\xC3".b, "\xE2\x82".b, "\xF0\x9F\x98".b].freeze
  LEDGER = []

  def setup
    @temporary = Pathname(Dir.mktmpdir('everypivot-utf8-'))
    available, status = Open3.capture2('locale', '-a')
    assert status.success?, 'Cannot discover available locales'
    names = available.lines.map(&:strip)
    @utf8_locale = %w[en_US.UTF-8 C.UTF-8].map do |preferred|
      names.find { |value| value.delete('-').downcase == preferred.delete('-').downcase }
    end.compact.first
  end

  def teardown
    FileUtils.remove_entry(@temporary.to_s) if @temporary && @temporary.exist?
  end

  def locales
    skip 'No supported UTF-8 locale is installed; locale matrix cannot run' unless @utf8_locale
    ['C', @utf8_locale]
  end

  def run_ruby(locale, script, *arguments, inputs: [])
    command = [RbConfig.ruby, script.to_s, *arguments.map(&:to_s)]
    env = {'LANG' => locale, 'LC_ALL' => locale, 'RUBYOPT' => nil}
    stdout, stderr, status = Open3.capture3(env, *command, chdir: ROOT.to_s)
    paths = [ROOT.join('tools/utf8_text.rb'), script, *inputs].map(&:to_s).select { |path| File.file?(path) }.uniq
    LEDGER << {
      'test' => name, 'command' => command, 'cwd' => ROOT.to_s, 'environment' => env,
      'runtime' => RUBY_DESCRIPTION, 'exit_code' => status.exitstatus,
      'input_sha256' => paths.each_with_object({}) { |path, hashes| hashes[path] = Digest::SHA256.file(path).hexdigest },
      'stdout_base64' => Base64.strict_encode64(stdout.b), 'stderr_base64' => Base64.strict_encode64(stderr.b)
    }
    File.binwrite(ENV['EVERYPIVOT_UTF8_LEDGER'], JSON.pretty_generate(LEDGER) + "\n") if ENV['EVERYPIVOT_UTF8_LEDGER']
    [stdout.b, stderr.b, status]
  end

  def successful(locale, script, *arguments, inputs: [])
    stdout, stderr, status = run_ruby(locale, script, *arguments, inputs: inputs)
    assert status.success?, "#{locale}: #{script.to_s.b.inspect}\nstdout=#{stdout.inspect}\nstderr=#{stderr.inspect}"
    [stdout, stderr]
  end

  def rejected(locale, script, *arguments, expected:, inputs: [])
    stdout, stderr, status = run_ruby(locale, script, *arguments, inputs: inputs)
    refute status.success?, "#{locale}: accepted invalid input: #{stdout.inspect}"
    assert_includes (stdout + stderr), expected.b
    refute_match(/invalid byte sequence in US-ASCII|Encoding::CompatibilityError|from .*\.rb:\d+/, stdout + stderr)
    [stdout, stderr]
  end

  def copy_repository(name = 'repo')
    destination = @temporary.join(name)
    destination.mkpath
    ROOT.children.each do |path|
      next if %w[.git dist node_modules .cache tmp .tmp].include?(path.basename.to_s)
      FileUtils.cp_r(path, destination.join(path.basename))
    end
    destination
  end

  def pattern
    {
      'id' => 'CTI_TEXT', 'name' => TEXT, 'version' => '1.0.0',
      'pattern_schema_version' => 1.5, 'assessment_mode' => 'evidence_only',
      'validation_state' => 'working_set', 'category' => 'CTI',
      'precision_tier' => 'low', 'robustness_class' => 'enumeration',
      'source' => 'file:pe:imphash', 'target' => 'file:bytes',
      'description' => TEXT, 'hazards' => [TEXT],
      'constraints' => {'provenance' => {'min_unique_sources' => 1}},
      'hops' => [{'via' => 'observed_in', 'direction' => 'out', 'form' => 'file:bytes'}]
    }
  end

  def registry_repository
    root = @temporary.join('données-東京-😀')
    root.mkpath
    FileUtils.cp_r(ROOT.join('schemas'), root.join('schemas'))
    FileUtils.cp_r(ROOT.join('tools'), root.join('tools'))
    root.join('graph-pivots/working-set').mkpath
    root.join('fixtures').mkpath
    # Psych 3 escapes non-BMP characters on dump; exercise literal UTF-8 bytes.
    File.binwrite(root.join('graph-pivots/working-set/CTI_TEXT.yaml'), YAML.dump(pattern).gsub('\\U0001F600', '😀'))
    File.binwrite(root.join('fixtures/opaque.bin'), "\x00\xFF\x80\r\n".b)
    root
  end

  def build_arguments(root, output_root = root)
    ['--repo-root', root, '--release', 'utf8-test', '--published-at', '2026-09-10',
     '--output', output_root.join('artifacts/registry-index.json'),
     '--site-data-root', output_root.join('site/data')]
  end

  def output_bytes(root)
    %w[artifacts site/data].each_with_object({}) do |directory, values|
      Dir.glob(root.join(directory, '**/*').to_s).sort.each do |path|
        values[Pathname(path).relative_path_from(root).to_s] = File.binread(path) if File.file?(path)
      end
    end
  end

  def archive_entries(path)
    entries = {}
    Zlib::GzipReader.open(path.to_s) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each { |entry| entries[entry.full_name] = entry.read.b if entry.file? }
      end
    end
    entries
  end

  def test_decoding_preserves_bytes_and_unicode_without_mutating_caller
    ['plain ASCII', TEXT, "é", "e\u0301"].each do |original|
      bytes = original.b.freeze
      decoded = EveryPivot::Utf8Text.decode(bytes, path: 'fixture.txt')
      assert_equal Encoding::UTF_8, decoded.encoding
      assert_equal original.b, decoded.b
      assert_equal Encoding::BINARY, bytes.encoding
    end
    refute_equal EveryPivot::Utf8Text.decode("é".b, path: 'composed'),
                 EveryPivot::Utf8Text.decode("e\u0301".b, path: 'decomposed')
    INVALID.each do |bytes|
      error = assert_raises(EveryPivot::Utf8Text::Error) { EveryPivot::Utf8Text.decode(bytes, path: 'bad.txt') }
      assert_includes error.message, 'Invalid UTF-8 in "bad.txt"'
    end
    error = assert_raises(EveryPivot::Utf8Text::Error) { EveryPivot::Utf8Text.decode("\uFEFFtext".b, path: 'bom.txt') }
    assert_includes error.message, 'UTF-8 BOM is not permitted'
    assert_equal "text\uFEFFinside", EveryPivot::Utf8Text.decode("text\uFEFFinside".b, path: 'inside.txt')
  end

  def test_helper_in_subprocesses_with_unicode_paths_and_ambient_encodings
    path = @temporary.join('texte-中文-😀.txt')
    script = @temporary.join('read.rb')
    File.binwrite(path, TEXT)
    File.binwrite(script, <<~SOURCE)
      require #{ROOT.join('tools/utf8_text.rb').to_s.dump}
      require 'json'
      begin
        text = EveryPivot::Utf8Text.read(ARGV.fetch(0))
        puts JSON.generate({'ambient' => Encoding.default_external.name, 'text' => text, 'encoding' => text.encoding.name})
      rescue EveryPivot::Utf8Text::Error => e
        abort e.message
      end
    SOURCE
    locales.each do |locale|
      stdout, = successful(locale, script, path, inputs: [path])
      data = JSON.parse(stdout)
      assert_equal(locale == 'C' ? 'US-ASCII' : 'UTF-8', data['ambient'])
      assert_equal TEXT, data['text']
      assert_equal 'UTF-8', data['encoding']
      INVALID.each do |bytes|
        File.binwrite(path, bytes)
        rejected(locale, script, path, expected: 'Invalid UTF-8', inputs: [path])
      end
      File.binwrite(path, TEXT)
    end
  end

  def test_non_ascii_markdown_html_json_and_embedded_javascript_gates
    root = copy_repository('surface-中文-😀')
    %w[README.md tools/README.md docs/releases/v0.6.0.md site/index.html].each do |relative|
      path = root.join(relative)
      File.binwrite(path, File.binread(path) + "\n<!-- #{TEXT} -->\n".b)
    end
    paths = %w[artifacts/registry-index.json artifacts/release-manifest.json site/data/registry-index.json]
    paths.each do |relative|
      path = root.join(relative)
      data = JSON.parse(EveryPivot::Utf8Text.read(path))
      data['utf8_fixture'] = TEXT
      File.binwrite(path, JSON.pretty_generate(data) + "\n")
    end
    registry = EveryPivot::Utf8Text.read(root.join('site/data/registry-index.json'))
    File.binwrite(root.join('site/data/registry-index.js'), "window.__EVERYPIVOT_REGISTRY__ = #{registry};\n")
    %w[check_release_metadata.rb check_site_snapshot.rb check_site_links.rb].each do |tool|
      results = locales.map do |locale|
        successful(locale, ROOT.join('tools', tool), '--repo-root', root,
                   inputs: [root.join('README.md'), root.join('site/index.html'), *paths.map { |path| root.join(path) }])
      end
      assert_equal results.first, results.last, tool
    end
  end

  def test_encoding_errors_are_controlled_for_every_declared_surface
    root = copy_repository
    cases = {
      'README.md' => %w[check_release_metadata.rb],
      'site/index.html' => %w[check_site_snapshot.rb check_site_links.rb],
      'artifacts/registry-index.json' => %w[check_release_metadata.rb check_site_snapshot.rb check_generated_freshness.rb],
      'site/data/registry-index.js' => %w[check_release_metadata.rb check_site_snapshot.rb]
    }
    cases.each do |relative, tools|
      path = root.join(relative)
      original = File.binread(path)
      File.binwrite(path, original + "\xF0\x9F\x98".b)
      tools.each do |tool|
        locales.each do |locale|
          out, err = rejected(locale, ROOT.join('tools', tool), '--repo-root', root,
                              expected: 'Invalid UTF-8', inputs: [path])
          assert_includes out + err, File.basename(relative).b
        end
      end
      File.binwrite(path, original)
    end
    path = root.join('artifacts/registry-index.json')
    File.binwrite(path, '{')
    locales.each do |locale|
      out, err = rejected(locale, ROOT.join('tools/check_release_metadata.rb'), '--repo-root', root,
                          expected: 'Invalid JSON', inputs: [path])
      refute_includes out + err, 'Invalid UTF-8'
    end
  end

  def test_registry_generation_and_binary_freshness_are_locale_independent
    root = registry_repository
    input = root.join('graph-pivots/working-set/CTI_TEXT.yaml')
    outputs = locales.map.with_index do |locale, index|
      destination = @temporary.join("output-#{index}-résultat-😀")
      successful(locale, ROOT.join('tools/build_registry_index.rb'), *build_arguments(root, destination), inputs: [input])
      data = JSON.parse(EveryPivot::Utf8Text.read(destination.join('artifacts/registry-index.json')))
      assert_equal TEXT, data['patterns'].first['summary']
      assert_includes File.binread(destination.join('site/data/pattern-sources.js')), TEXT.b
      assert_equal File.binread(input), archive_entries(destination.join('artifacts/patterns.tar.gz'))['graph-pivots/working-set/CTI_TEXT.yaml']
      assert_equal "\x00\xFF\x80\r\n".b, archive_entries(destination.join('artifacts/fixtures.tar.gz'))['fixtures/opaque.bin']
      bytes = output_bytes(destination).reject { |path, _| path.end_with?('.tar.gz') }
      FileUtils.cp_r(destination.join('artifacts'), root) if index.zero?
      root.join('site').mkpath
      FileUtils.cp_r(destination.join('site/data'), root.join('site')) if index.zero?
      bytes
    end
    assert_equal outputs.first, outputs.last
    locales.each do |locale|
      successful(locale, ROOT.join('tools/check_generated_freshness.rb'), '--repo-root', root, inputs: [input])
    end
    # Even semantically harmless textual byte changes still fail freshness.
    path = root.join('site/data/registry-index.json')
    File.binwrite(path, File.binread(path) + "\n")
    locales.each do |locale|
      rejected(locale, ROOT.join('tools/check_generated_freshness.rb'), '--repo-root', root, expected: 'is stale', inputs: [path])
    end
  end

  def test_refused_registry_generation_preserves_all_output_bytes
    root = registry_repository
    input = root.join('graph-pivots/working-set/CTI_TEXT.yaml')
    original = File.binread(input)
    successful('C', ROOT.join('tools/build_registry_index.rb'), *build_arguments(root), inputs: [input])
    existing = output_bytes(root)
    [[original + "\xE2\x82".b, 'Invalid UTF-8'], ["\uFEFF".b + original, 'UTF-8 BOM is not permitted'],
     ['hops: [', 'YAML read/parse failed']].each do |bytes, diagnostic|
      File.binwrite(input, bytes)
      locales.each do |locale|
        rejected(locale, ROOT.join('tools/build_registry_index.rb'), *build_arguments(root), expected: diagnostic, inputs: [input])
        assert_equal existing, output_bytes(root)
      end
    end
    File.binwrite(input, original)
    schema = root.join('schemas/pivot_pattern.schema.json')
    [["\xFF".b, 'Invalid UTF-8'], ['{', 'Pattern schema unavailable']].each do |bytes, diagnostic|
      File.binwrite(schema, bytes)
      locales.each do |locale|
        rejected(locale, ROOT.join('tools/build_registry_index.rb'), *build_arguments(root), expected: diagnostic, inputs: [schema])
        assert_equal existing, output_bytes(root)
      end
    end
  end

  def test_profile_generators_preserve_multilingual_text_and_refuse_bad_fixtures
    [
      ['generate_query_profile_demo.rb', 'adapters/query-profiles/neo4j_cypher_v0.yml', 'fixture_graph_location', '--fixture-graph'],
      ['generate_stix_mapping_profile_demo.rb', 'adapters/query-profiles/opencti_stix_v0.yml', 'fixture_mapping_location', '--fixture-mapping']
    ].each do |tool, profile_relative, fixture_key, fixture_flag|
      profile = YAML.safe_load(EveryPivot::Utf8Text.read(ROOT.join(profile_relative)), aliases: false)
      target = profile.fetch('targets').first
      fixture = JSON.parse(EveryPivot::Utf8Text.read(ROOT.join(target.fetch(fixture_key))))
      fixture['blocked_assertions'] << TEXT
      input = @temporary.join('fixture-中文-😀.json')
      output = @temporary.join('résultat-😀.txt')
      File.binwrite(input, JSON.pretty_generate(fixture))
      arguments = ['--repo-root', ROOT, '--profile', ROOT.join(profile_relative), '--pattern-id', target.fetch('pattern_id'),
                   fixture_flag, input, '--output', output]
      results = locales.map do |locale|
        successful(locale, ROOT.join('tools', tool), *arguments, inputs: [input])
        File.binread(output)
      end
      assert_equal results.first, results.last
      assert_includes results.first, TEXT.b
      [["\xF0\x9F\x98".b, 'Invalid UTF-8'], ['{', 'Invalid JSON']].each do |bytes, diagnostic|
        File.binwrite(input, bytes)
        locales.each do |locale|
          rejected(locale, ROOT.join('tools', tool), *arguments, expected: diagnostic, inputs: [input])
          assert_equal results.first, File.binread(output)
        end
      end
      bad_profile = @temporary.join('bad-profile.yml')
      File.binwrite(bad_profile, 'targets: [')
      locales.each do |locale|
        rejected(locale, ROOT.join('tools', tool), '--profile', bad_profile, '--output', output,
                 expected: 'Invalid YAML', inputs: [bad_profile])
        assert_equal results.first, File.binread(output)
      end
    end
  end

  def test_provenance_json_reader_preserves_supplied_multilingual_evidence
    data = JSON.parse(EveryPivot::Utf8Text.read(ROOT.join('fixtures/package-repository-provenance/version-declaration.record.json')))
    data['declaration']['evidence']['publisher'] = TEXT
    input = @temporary.join('provenance-中文-😀.json')
    output = @temporary.join('provenance-result-😀.json')
    File.binwrite(input, JSON.pretty_generate(data))
    original = File.binread(input)
    results = locales.map do |locale|
      successful(locale, ROOT.join('tools/package_repository_provenance.rb'), '--input', input, '--output', output, inputs: [input])
      result = JSON.parse(EveryPivot::Utf8Text.read(output))
      assert_equal TEXT, result.dig('declaration', 'evidence', 'publisher')
      assert_equal data['declaration'], result['declaration']
      assert_equal original, File.binread(input)
      output.delete
      result
    end
    assert_equal results.first, results.last
    [["\xFF".b, 'Invalid UTF-8'], ['{', 'Invalid JSON'], ["\uFEFF{}", 'UTF-8 BOM is not permitted']].each do |bytes, diagnostic|
      File.binwrite(input, bytes)
      locales.each do |locale|
        rejected(locale, ROOT.join('tools/package_repository_provenance.rb'), '--input', input, '--output', output,
                 expected: diagnostic, inputs: [input])
        refute output.exist?
      end
    end
  end

  def test_auxiliary_readers_reject_malformed_text_from_copied_unicode_roots
    root = copy_repository('checks-中文-😀')
    cases = [
      ['docs/RELATION_CATALOG.md', 'check_relation_catalog.rb', []],
      ['docs/RELATION_CATALOG.md', 'check_cti_promotion_lint.rb', []],
      ['fixtures/validator_suite.yml', 'check_fixture_suite.rb', []],
      ['adapters/query-profiles/neo4j_cypher_v0.yml', 'check_query_profile_suite.rb', []],
      ['schemas/package_repository_provenance.v1.schema.json', 'package_repository_provenance.rb',
       ['--input', root.join('fixtures/package-repository-provenance/version-declaration.record.json'), '--check']]
    ]
    cases.each do |relative, tool, arguments|
      path = root.join(relative)
      original = File.binread(path)
      File.binwrite(path, original + "\xFF".b)
      locales.each do |locale|
        out, err = rejected(locale, root.join('tools', tool), *arguments, expected: 'Invalid UTF-8', inputs: [path])
        assert_includes out + err, File.basename(relative).b
      end
      File.binwrite(path, original)
    end

    path = @temporary.join('patterns.json')
    File.binwrite(path, "\xFF".b)
    locales.each do |locale|
      rejected(locale, root.join('tools/check_reachable_history.rb'), '--patterns-file', path,
               expected: 'Invalid UTF-8', inputs: [path])
    end
  end

  def test_relation_catalog_retains_warning_only_inventory_semantics
    library = @temporary.join('library')
    library.mkpath
    path = library.join('CTI_TEXT.yaml')
    File.binwrite(path, "\xFF".b)
    locales.each do |locale|
      stdout, stderr = successful(locale, ROOT.join('tools/check_relation_catalog.rb'), library, inputs: [path])
      assert_includes stdout + stderr, 'Invalid UTF-8'
      assert_includes stdout + stderr, 'CTI_TEXT.yaml'
    end
  end
end
