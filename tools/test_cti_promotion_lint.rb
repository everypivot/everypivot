#!/usr/bin/env ruby

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'

class CtiPromotionLintTest < Minitest::Test
  REPO_ROOT = Pathname(__dir__).join('..').expand_path

  def run_lint(patterns:, fixtures:)
    Open3.capture3(
      RbConfig.ruby,
      REPO_ROOT.join('tools', 'check_cti_promotion_lint.rb').to_s,
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
end
