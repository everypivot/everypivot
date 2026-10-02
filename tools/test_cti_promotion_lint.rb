#!/usr/bin/env ruby

require 'digest'
require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'
require_relative 'utf8_text'
require_relative 'check_semantic_fixture_hashes'

class CtiPromotionLintTest < Minitest::Test
  REPO_ROOT = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: __FILE__)).join('..').expand_path

  def run_lint(patterns:, fixtures:, repo_root: REPO_ROOT)
    Open3.capture3(
      RbConfig.ruby,
      REPO_ROOT.join('tools', 'check_cti_promotion_lint.rb').to_s,
      '--repo-root',
      repo_root.to_s,
      '--catalog',
      REPO_ROOT.join('docs', 'RELATION_CATALOG.md').to_s,
      '--patterns',
      patterns.to_s,
      '--fixtures',
      fixtures.to_s,
      chdir: REPO_ROOT.to_s
    )
  end

  def write_file(path, content)
    FileUtils.mkdir_p(path.dirname)
    path.write(content)
  end

  def write_safe_pattern(root)
    write_file(
      root.join('working-set', 'CTI_SAFE_EMAIL_IP.yaml'),
      <<~YAML
        id: CTI_SAFE_EMAIL_IP
        category: CTI
        source: inet:ipv4
        target: email:message
        hops:
        - via: originating_ip_for
          direction: in
          form: email:message
        constraints:
          degree_caps:
            inet:ipv4: 1000
          negative_nodes:
          - form: inet:ipv4
            list: example_vpn_ranges
      YAML
    )
  end

  def test_cataloged_pattern_and_documentation_fixture_pass
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      fixtures = root.join('fixtures')
      write_safe_pattern(patterns)
      write_file(
        fixtures.join('safe_fixture.json'),
        <<~JSON
          {
            "fixture_id": "safe_fixture",
            "ip": "203.0.113.45",
            "domain": "mail.ops.example.net",
            "email": "sample@example.invalid",
            "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "cmd": "metadata label only",
            "artifact": "dashboard.html"
          }
        JSON
      )

      stdout, stderr, status = run_lint(patterns: patterns, fixtures: fixtures)
      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
      assert_includes stdout, 'CTI promotion lint passed'
    end
  end

  def test_generated_review_relation_and_sidecar_key_fail
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      fixtures = root.join('fixtures')
      write_file(
        patterns.join('working-set', 'CTI_BAD_REVIEW_RELATION.yaml'),
        <<~YAML
          id: CTI_BAD_REVIEW_RELATION
          category: CTI
          source: inet:ipv4
          target: email:message
          source_scope_caveat: should stay outside pattern YAML
          hops:
          - via: supports_assessment_context
            direction: out
            form: email:message
        YAML
      )

      stdout, _stderr, status = run_lint(patterns: patterns, fixtures: fixtures)
      refute status.success?, stdout
      assert_includes stdout, 'supports_assessment_context'
      assert_includes stdout, 'sidecar-only key `source_scope_caveat`'
      assert_equal 1, stdout.scan('supports_assessment_context').length
    end
  end

  def test_branch_of_compound_catalog_entry_passes
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      fixtures = root.join('fixtures')
      write_file(
        patterns.join('working-set', 'CTI_BRANCH_SOURCE.yaml'),
        <<~YAML
          id: CTI_BRANCH_SOURCE
          category: CTI
          source: cloud:application:uid
          target: auth:event
          hops:
          - via: contains_auth_event
            direction: out
            form: auth:event
        YAML
      )

      stdout, stderr, status = run_lint(patterns: patterns, fixtures: fixtures)
      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def test_uncataloged_namespace_fails
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      fixtures = root.join('fixtures')
      write_file(
        patterns.join('working-set', 'CTI_UNREVIEWED_NAMESPACE.yaml'),
        <<~YAML
          id: CTI_UNREVIEWED_NAMESPACE
          category: CTI
          source: vendorx:tenant
          target: email:message
          hops:
          - via: originating_ip_for
            direction: in
            form: email:message
        YAML
      )

      stdout, _stderr, status = run_lint(patterns: patterns, fixtures: fixtures)
      refute status.success?, stdout
      assert_includes stdout, 'unreviewed namespace `vendorx`'
    end
  end

  def test_constraint_form_with_reviewed_namespace_can_be_novel
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      fixtures = root.join('fixtures')
      write_file(
        patterns.join('working-set', 'CTI_NOVEL_CONSTRAINT_FORM.yaml'),
        <<~YAML
          id: CTI_NOVEL_CONSTRAINT_FORM
          category: CTI
          source: inet:ipv4
          target: email:message
          hops:
          - via: originating_ip_for
            direction: in
            form: email:message
          constraints:
            degree_caps:
              inet:custom:role: 10
            negative_nodes:
            - form: inet:custom:role
              list: example_constraint_only_values
        YAML
      )

      stdout, stderr, status = run_lint(patterns: patterns, fixtures: fixtures)
      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def test_constraint_form_with_unreviewed_namespace_fails
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      fixtures = root.join('fixtures')
      write_file(
        patterns.join('working-set', 'CTI_BAD_CONSTRAINT_NAMESPACE.yaml'),
        <<~YAML
          id: CTI_BAD_CONSTRAINT_NAMESPACE
          category: CTI
          source: inet:ipv4
          target: email:message
          hops:
          - via: originating_ip_for
            direction: in
            form: email:message
          constraints:
            negative_nodes:
            - form: vendorx:custom_form
              list: example_constraint_only_values
        YAML
      )

      stdout, _stderr, status = run_lint(patterns: patterns, fixtures: fixtures)
      refute status.success?, stdout
      assert_includes stdout, 'unreviewed namespace `vendorx`'
    end
  end

  def test_sensitive_fixture_material_fails
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      fixtures = root.join('fixtures')
      write_safe_pattern(patterns)
      # Assemble the AWS-key-shaped literal at runtime so the source file does
      # not contain a hard-coded AKIA[0-9A-Z]{16} pattern that GitHub secret
      # scanning would alert on. The lint still sees the assembled string in
      # the generated fixture and is expected to flag it.
      aws_key_literal = 'AKIA' + 'ABCDEFGHIJKLMNOP'
      write_file(
        fixtures.join('bad_fixture.json'),
        <<~JSON
          {
            "ip": "8.8.8.8",
            "domain": "control.example-malware.com",
            "hash": "5d41402abc4b2a76b9719d911017c592",
            "cve": "CVE-2024-12345",
            "aws_key": "#{aws_key_literal}"
          }
        JSON
      )

      stdout, _stderr, status = run_lint(patterns: patterns, fixtures: fixtures)
      refute status.success?, stdout
      assert_includes stdout, 'non-documentation IPv4 address `8.8.8.8`'
      assert_includes stdout, 'non-example domain `control.example-malware.com`'
      assert_includes stdout, 'plausible real hash'
      assert_includes stdout, 'CVE identifier `CVE-2024-12345`'
      assert_includes stdout, 'AWS access key id'
    end
  end

  def provenance_fixture_paths
    %w[version-declaration.record.json mirror-reference.record.json snapshot-v1.vector.json]
      .map { |name| Pathname('fixtures').join('package-repository-provenance', name) }
  end

  def test_exact_reviewed_provenance_fixtures_pass_in_a_portable_copy
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      write_safe_pattern(patterns)
      provenance_fixture_paths.each do |relative|
        write_file(root.join(relative), REPO_ROOT.join(relative).binread)
      end

      stdout, stderr, status = run_lint(patterns: patterns, fixtures: root.join('fixtures'), repo_root: root)
      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
      assert_includes stdout, '3 fixture files'
    end
  end

  def test_reviewed_hashes_are_rejected_when_fixture_is_renamed_or_copied_elsewhere
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      write_safe_pattern(patterns)
      provenance_fixture_paths.each do |relative|
        content = REPO_ROOT.join(relative).binread
        [relative.dirname.join('renamed-' + relative.basename.to_s), Pathname('fixtures/elsewhere').join(relative.basename)].each do |relocated|
          target = root.join(relocated)
          write_file(target, content)
          stdout, _stderr, status = run_lint(patterns: patterns, fixtures: target, repo_root: root)
          refute status.success?, "relocated reviewed fixture passed: #{relocated}\n#{stdout}"
          assert_includes stdout, 'plausible real hash'
        end
      end
    end
  end

  def test_changing_reviewed_fixture_bytes_revokes_hash_exception
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      write_safe_pattern(patterns)
      provenance_fixture_paths.each do |relative|
        target = root.join(relative)
        write_file(target, REPO_ROOT.join(relative).binread + "\n")
        stdout, _stderr, status = run_lint(patterns: patterns, fixtures: target, repo_root: root)
        refute status.success?, "changed reviewed fixture passed: #{relative}\n#{stdout}"
        assert_includes stdout, 'plausible real hash'
      end
    end
  end

  def test_foreign_hashes_and_other_scanner_rules_are_not_exempted
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      write_safe_pattern(patterns)
      relative = provenance_fixture_paths.last
      target = root.join(relative)
      foreign_hash = Digest::SHA256.hexdigest('unreviewed synthetic hash')
      content = REPO_ROOT.join(relative).binread + "\n#{foreign_hash}\n8.8.8.8\nCVE-2024-12345\n"
      write_file(target, content)
      stdout, _stderr, status = run_lint(patterns: patterns, fixtures: target, repo_root: root)
      refute status.success?, stdout
      assert_includes stdout, "plausible real hash `#{foreign_hash}`"
      assert_includes stdout, 'non-documentation IPv4 address `8.8.8.8`'
      assert_includes stdout, 'CVE identifier `CVE-2024-12345`'
      assert_includes stdout, 'plausible real hash `2b83ba6df9942b489462748a1fb2fe76dc81f4a6c13c8a2f25917233a45775e7`'
    end
  end

  def semantic_review
    JSON.parse(EveryPivot::CtiPromotionLint::SEMANTIC_FIXTURE_REVIEW_PATH.binread)
  end

  def test_all_semantic_fixture_hashes_have_independent_reproductions
    result = EveryPivot::SemanticFixtureHashReview.check
    assert_equal 80, result.fetch('json_files')
    assert_equal 56, result.fetch('exception_files')
    assert_equal 255, result.fetch('unique_values')
    assert_equal 1, result.fetch('derivation_counts').fetch('explicit_synthetic_selector_vector')
  end

  def test_exact_semantic_fixture_bytes_pass_in_a_portable_copy
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      patterns = root.join('graph-pivots')
      write_safe_pattern(patterns)
      semantic_review.fetch('inventory').each_key do |relative|
        write_file(root.join(relative), REPO_ROOT.join(relative).binread)
      end
      stdout, stderr, status = run_lint(patterns: patterns, fixtures: root.join('fixtures'), repo_root: root)
      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
      assert_includes stdout, '80 fixture files'
    end
  end

  def test_every_semantic_hash_exception_requires_exact_bytes_and_path
    lint = EveryPivot::CtiPromotionLint
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      semantic_review.fetch('files').each do |relative, entry|
        content = REPO_ROOT.join(relative).binread
        original = root.join(relative)
        write_file(original, content)
        assert_equal entry.fetch('allowed_hex').sort, lint.reviewed_fixture_hashes(original, content, root).to_a.sort, relative
        write_file(original, content + "\n")
        assert_empty lint.reviewed_fixture_hashes(original, content + "\n", root), relative
        assert lint.check_fixture_file(original, root).any? { |error| error.include?('plausible real hash') }, relative
        renamed = original.dirname.join('renamed-' + original.basename.to_s)
        relocated = root.join('fixtures/elsewhere', original.basename)
        [renamed, relocated].each do |target|
          write_file(target, content)
          assert_empty lint.reviewed_fixture_hashes(target, content, root), target.to_s
          assert lint.check_fixture_file(target, root).any? { |error| error.include?('plausible real hash') }, target.to_s
        end
      end
    end
  end

  def test_semantic_hash_exceptions_do_not_exempt_unknown_hashes_or_other_rules
    lint = EveryPivot::CtiPromotionLint
    relative, entry = semantic_review.fetch('files').first
    file = REPO_ROOT.join(relative)
    allowed = lint.reviewed_fixture_hashes(file, file.binread, REPO_ROOT)
    known = entry.fetch('allowed_hex').first
    unknown = Digest::SHA256.hexdigest('new unreviewed synthetic value')
    errors = []
    line = [known, unknown, '8.8.8.8', 'https://unreviewed-host.com', 'CVE-2024-12345',
            'AKIA' + 'ABCDEFGHIJKLMNOP', 'curl https://example.test/fixture', 'requires_private_review'].join(' ')
    lint.scan_fixture_line(file, line, 1, errors, allowed)
    refute errors.any? { |error| error.include?("plausible real hash `#{known}`") }
    ['plausible real hash `' + unknown + '`', 'non-documentation IPv4', 'non-example URL',
     'non-example domain', 'CVE identifier', 'AWS access key id', 'download command', 'review-gate vocabulary'].each do |message|
      assert errors.any? { |error| error.include?(message) }, message
    end
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      target = root.join(relative)
      write_file(target, file.binread + "\n" + unknown)
      failures = lint.check_fixture_file(target, root)
      assert failures.any? { |error| error.include?(unknown) }
      assert failures.any? { |error| error.include?(known) }, 'Changed bytes must revoke even previously reviewed values'
    end
  end

  def test_semantic_review_manifest_cannot_silently_change_allowances
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      %w[check_cti_promotion_lint.rb utf8_text.rb].each do |name|
        write_file(root.join(name), REPO_ROOT.join('tools', name).binread)
      end
      manifest = root.join('data/reviewed_semantic_fixture_hashes.json')
      write_file(manifest, EveryPivot::CtiPromotionLint::SEMANTIC_FIXTURE_REVIEW_PATH.binread + "\n")
      _stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-r', root.join('check_cti_promotion_lint.rb').to_s,
        '-e', 'EveryPivot::CtiPromotionLint.semantic_fixture_hashes')
      refute status.success?
      assert_includes stderr, 'explicit re-review required'
    end
  end

  def test_escaped_json_url_tokens_keep_host_scanning
    lint = EveryPivot::CtiPromotionLint
    safe = JSON.generate('source' => JSON.generate('url' => 'https://registry.example'))
    errors = []
    lint.scan_fixture_line('synthetic.json', safe, 1, errors)
    assert_empty errors
    unsafe = JSON.generate('source' => JSON.generate('url' => 'https://unreviewed-host.com'))
    lint.scan_fixture_line('synthetic.json', unsafe, 2, errors)
    assert errors.any? { |error| error.include?('non-example URL `https://unreviewed-host.com`') }
    assert errors.any? { |error| error.include?('non-example domain `unreviewed-host.com`') }
    # A backslash cannot hide a later real hostname from the independent scan.
    lint.scan_fixture_line('synthetic.json', 'https://registry.example\\@unreviewed-host.com', 3, errors)
    assert errors.any? { |error| error.start_with?('synthetic.json:3:') && error.include?('unreviewed-host.com') }
  end
end
