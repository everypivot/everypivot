#!/usr/bin/env ruby
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require_relative 'stix_mapping_validation'

class StixMappingValidationTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  FIXTURE = 'fixtures/query-profiles/opencti/cti_sample_imphash_cluster.stix_mapping.json'
  BUNDLE = 'adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json'

  def test_complete_syntax_calendar_and_precision
    validator = EveryPivot::StixMappingValidation
    assert_equal '2024-02-29T00:00:00.000Z', validator.timestamp('2024-02-29')
    %w[2026-05-20T12:34:56Z 2026-05-20T12:34:56.123456Z].each { |value| assert_equal value, validator.timestamp(value) }
    [nil, 1, '2026-02-30', '2026-02-30T00:00:00Z', '2026-05-20Tgarbage', '2026-05-20T25:00:00Z', '2026-05-20T00:00:00Zjunk', '2026-05-20T00:00:00+01:00'].each do |value|
      assert_raises(ArgumentError, value.inspect) { validator.timestamp(value) }
    end
    assert_raises(ArgumentError) { validator.timestamp('2026-05-20T00:00:00.1Z', milliseconds_required: true) }
    %w[2026-05-20T12:34:60Z 2016-12-31T23:59:60Z].each do |value|
      error = assert_raises(ArgumentError) { validator.timestamp(value) }
      assert_includes error.message, 'leap-second timestamp inputs are unsupported'
    end
  end

  def with_copy
    Dir.mktmpdir('stix-mapping-test') do |dir|
      %w[tools adapters fixtures graph-pivots schemas].each { |name| FileUtils.cp_r(File.join(ROOT, name), dir) }
      fixture = JSON.parse(File.read(File.join(dir, FIXTURE)))
      yield dir, fixture
    end
  end

  def generate(dir, fixture)
    File.write(File.join(dir, FIXTURE), JSON.pretty_generate(fixture))
    Open3.capture3(RbConfig.ruby, 'tools/generate_stix_mapping_profile_demo.rb', '--output', BUNDLE, chdir: dir)
  end

  def test_generator_refuses_invalid_values_without_overwriting
    with_copy do |dir, fixture|
      original = File.binread(File.join(dir, BUNDLE))
      mutations = [->(f) { f['targets'][0]['seen'] = '2026-05-20T25:00:00Z' },
                   ->(f) { f['targets'][0]['seen'] = '2026-02-30T00:00:00Z' },
                   ->(f) { f['created'] = '2026-05-27Tgarbage' },
                   ->(f) { f['expected_suppressed_targets'][0]['reason'] = 42 }]
      mutations.each do |mutation|
        f = Marshal.load(Marshal.dump(fixture)); mutation.call(f)
        _stdout, stderr, status = generate(dir, f)
        assert_equal 2, status.exitstatus, stderr
        assert_match(/timestamp invalid|extension schema validation failed/, stderr)
        assert_equal original, File.binread(File.join(dir, BUNDLE))
      end
    end
  end

  def test_window_consistency_is_in_suite_not_serializer
    with_copy do |dir, fixture|
      {'2016-05-25' => false, '2016-05-26' => true, '2026-05-24' => true, '2026-05-25' => false}.each do |date, valid|
        fixture['targets'][0]['seen'] = date
        _, stderr, status = generate(dir, fixture)
        assert status.success?, stderr # Serializer maps already-selected entries.
        stdout, stderr, status = Open3.capture3(RbConfig.ruby, 'tools/check_query_profile_suite.rb', chdir: dir)
        assert_equal valid, status.success?, [date, stdout, stderr].join("\n")
        assert_includes stdout, 'outside the temporal window' unless valid
      end
    end
  end

  def test_regeneration_is_unchanged
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, File.join(ROOT, 'tools/generate_stix_mapping_profile_demo.rb'))
    assert status.success?, stderr
    assert_equal File.binread(File.join(ROOT, BUNDLE)), stdout.b
  end

  def test_creator_contract_and_reordered_reference_closure
    bundle = JSON.parse(File.read(File.join(ROOT, BUNDLE)))
    ref = bundle['objects'].find { |o| o['type'] == 'extension-definition' }['created_by_ref']
    validate = ->(b) { EveryPivot::StixMappingValidation.creator_errors(b['objects'], ref) }
    extension = bundle['objects'].find { |o| o['type'] == 'extension-definition' }
    identity = bundle['objects'].find { |o| o['type'] == 'identity' }
    assert_equal extension['created'], extension['modified'] # First version of the replacement extension.
    assert_equal identity['created'], identity['modified']
    assert_equal 'EveryPivot Project', identity['name']
    assert_equal 'identity--c0ab47b4-28e6-48b6-bc65-1ad2feee67c6', identity['id']
    assert_equal 'extension-definition--f88d909d-5287-4f9a-8413-c1bcbc178d29', extension['id']
    assert_equal identity['id'], extension['created_by_ref']
    assert_equal 'group', identity['identity_class']
    refute identity.key?('contact_information')
    historical_dir = File.join(ROOT, 'adapters/opencti/tests/historical-fixtures')
    %w[historical-0.1.0.bundle.json synthetic-creator-0.2.0.bundle.json].each do |name|
      historical = JSON.parse(File.read(File.join(historical_dir, name)))
      refute_equal historical['id'], bundle['id']
      old_extension = historical['objects'].find { |o| o['type'] == 'extension-definition' }
      refute_equal old_extension['id'], extension['id']
      old_identity = historical['objects'].find { |o| o['type'] == 'identity' }
      refute_equal old_identity['id'], identity['id'] if old_identity
      %w[note observed-data relationship].each do |type|
        old_object = historical['objects'].find { |o| o['type'] == type }
        current = bundle['objects'].find { |o| o['type'] == type }
        assert_equal old_object['id'], current['id']
        assert_equal old_object['created'], current['created']
        assert_operator DateTime.iso8601(current['modified']), :>, DateTime.iso8601(old_object['modified'])
      end
    end
    assert_empty validate.call(bundle)
    assert_empty validate.call({'objects' => bundle['objects'].reverse})
    [nil, '', 'not-an-id', bundle['objects'][1]['id']].each do |bad|
      b = Marshal.load(Marshal.dump(bundle)); b['objects'][0]['created_by_ref'] = bad
      assert_includes validate.call(b), 'extension-definition.created_by_ref must be an Identity identifier'
    end
    b = Marshal.load(Marshal.dump(bundle)); b['objects'].reject! { |o| o['type'] == 'identity' }
    assert_includes validate.call(b), 'extension-definition.created_by_ref is dangling'
    b = Marshal.load(Marshal.dump(bundle)); b['objects'].find { |o| o['type'] == 'identity' }['type'] = 'file'
    assert_includes validate.call(b), 'extension-definition.created_by_ref targets wrong object type'
  end

  def test_refused_creator_authority_duplicate_and_supplied_ids_preserve_output
    with_copy do |dir, fixture|
      original = File.binread(File.join(dir, BUNDLE))
      mutations = [
        [->(f) { f['stix'].delete('created_by_ref') }, /Identity identifier/],
        [->(f) { f['extension_creator'] = nil }, /all bundle objects/],
        [->(f) { f['stix']['created_by_ref'] = 'identity--00000000-0000-4000-8000-000000000001' }, /dangling/],
        [->(f) { f['extension_creator']['type'] = 'file' }, /wrong object type/],
        [->(f) { f['extension_creator']['x_opencti_created_by_ref'] = f['extension_creator']['id'] }, /forbidden authority properties/],
        [->(f) { f['targets'] << Marshal.load(Marshal.dump(f['targets'][0])) }, /duplicate object IDs/],
        [->(f) { f['source']['stix_ref'] = 'file--11111111-1111-4111-8111-111111111111' }, /must be deterministic UUIDv5/],
        [->(f) { f['source'].delete('name'); f['source']['hashes'] = {} }, /requires at least one identifier-contributing/],
        [->(f) { f['modified'] = '2020-01-01T00:00:00.000Z' }, /modified precedes created/]
      ]
      mutations.each do |mutation, diagnostic|
        f = Marshal.load(Marshal.dump(fixture)); mutation.call(f)
        _, stderr, status = generate(dir, f)
        assert_equal 2, status.exitstatus, stderr
        assert_match diagnostic, stderr
        assert_equal original, File.binread(File.join(dir, BUNDLE))
      end
    end
  end
end
