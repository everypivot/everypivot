#!/usr/bin/env ruby

require 'ipaddr'
require 'optparse'
require 'pathname'
require 'set'
require 'yaml'

module EveryPivot
  module CtiPromotionLint
    REPO_ROOT = Pathname(__dir__).join('..').expand_path

    CATALOG_SECTIONS = {
      'Source forms' => :source,
      'Target forms' => :target,
      'Hop relation values' => :via,
      'Hop forms' => :form
    }.freeze

    DEPRECATED_CATALOG_SECTIONS = {
      'Deprecated source forms' => :source,
      'Deprecated target forms' => :target,
      'Deprecated hop relation values' => :via,
      'Deprecated hop forms' => :form
    }.freeze

    PATTERN_EXTENSIONS = %w[.yaml .yml].freeze
    FIXTURE_EXTENSIONS = %w[.json .yaml .yml .cypher].freeze
    VALIDATOR_FIXTURE_EXCLUSIONS = [
      'fixtures/validator_suite.yml',
      %r{\Afixtures/cases/}
    ].freeze

    BANNED_REVIEW_RELATIONS = [
      /\bsupports_[a-z0-9_]*\b/i,
      /\brequires_private_review\b/i,
      /\bexcluded_private_data\b/i,
      /\breview[-_]?gate\b/i,
      /\bprivate[-_]?gate\b/i,
      /\bpromotion[-_]?readiness\b/i,
      /\banalyst[-_]?sign[-_]?off\b/i
    ].freeze

    # These are not schema fields. They come from the doctrine's review concept
    # labels and prohibited graph encodings, and must stay outside pattern YAML.
    SIDECAR_ONLY_KEYS = %w[
      source_scope_caveat
      attribution_confidence
      attribution_confidence_context
      vulnerability_priority
      vulnerability_priority_context
      defensive_control_context
      cloud_saas_trust_boundary_context
      it_ot_segmentation_context
      extortion_business_continuity_context
      fraud_account_control_context
      source_method
      collection_method
      final_assessment
      operational_effect
      private_gate_state
      review_gate_state
    ].freeze

    SPECIAL_DOMAIN_SUFFIXES = %w[
      example
      example.com
      example.net
      example.org
      invalid
      test
      localhost
    ].freeze
    SENSITIVE_DOMAIN_TLDS = %w[
      ai app biz cloud cn co com dev edu gov info int io mil net online org ru
      site top uk us xyz
    ].freeze

    DOC_IPV4_RANGES = [
      IPAddr.new('192.0.2.0/24'),
      IPAddr.new('198.51.100.0/24'),
      IPAddr.new('203.0.113.0/24')
    ].freeze

    CREDENTIAL_PATTERNS = [
      [/AKIA[0-9A-Z]{16}/, 'AWS access key id'],
      [/ASIA[0-9A-Z]{16}/, 'AWS session key id'],
      [/AIza[0-9A-Za-z_-]{35}/, 'Google API key'],
      [/gh[pousr]_[0-9A-Za-z_]{36,}/, 'GitHub token'],
      [/xox[baprs]-[0-9A-Za-z-]{10,}/, 'Slack token'],
      [/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/, 'private key block']
    ].freeze

    COMMAND_PATTERNS = [
      [/\brule\s+[A-Za-z0-9_]+\s*\{/, 'YARA rule body'],
      [/\b(?:powershell(?:\.exe)?|cmd(?:\.exe|\s+\/c)|bash\s+-c|sh\s+-c)\b/i, 'shell command'],
      [/\b(?:curl|wget)\s+(?:-[A-Za-z]|https?:\/\/|\w)/i, 'download command'],
      [/\b(?:nc|netcat|nmap|msfconsole|meterpreter)\b/i, 'offensive or scanning command'],
      [/\b(?:shellcode|reverse shell|exploit payload)\b/i, 'exploit mechanic']
    ].freeze

    module_function

    def parse_args(argv)
      options = {
        repo_root: REPO_ROOT,
        pattern_roots: [],
        fixture_roots: [],
        catalog_path: nil
      }

      parser = OptionParser.new do |opt|
        opt.banner = 'Usage: check_cti_promotion_lint.rb [options]'

        opt.on('--repo-root PATH', 'Repository root for default paths') do |value|
          options[:repo_root] = Pathname(value).expand_path
        end

        opt.on('--patterns PATH', 'Pattern file or directory to lint; repeatable') do |value|
          options[:pattern_roots] << Pathname(value).expand_path
        end

        opt.on('--fixtures PATH', 'Fixture file or directory to lint; repeatable') do |value|
          options[:fixture_roots] << Pathname(value).expand_path
        end

        opt.on('--catalog PATH', 'Relation catalog path') do |value|
          options[:catalog_path] = Pathname(value).expand_path
        end
      end

      parser.parse!(argv)
      repo_root = options[:repo_root]
      options[:catalog_path] ||= repo_root.join('docs', 'RELATION_CATALOG.md')
      options[:pattern_roots] = [repo_root.join('graph-pivots')] if options[:pattern_roots].empty?
      options[:fixture_roots] = [repo_root.join('fixtures')] if options[:fixture_roots].empty?
      [options, parser]
    end

    def collect_files(root, extensions)
      return [] unless root.exist?
      return [root] if root.file? && extensions.include?(root.extname)

      Dir.glob(root.join('**', '*').to_s, File::FNM_DOTMATCH)
         .map { |path| Pathname(path) }
         .select { |path| path.file? && extensions.include?(path.extname) }
         .sort
    end

    def validator_fixture_case?(file, repo_root)
      relative = file.relative_path_from(repo_root).to_s
      VALIDATOR_FIXTURE_EXCLUSIONS.any? do |entry|
        entry.is_a?(Regexp) ? relative.match?(entry) : relative == entry
      end
    rescue ArgumentError
      false
    end

    def load_catalog(path)
      raise "Relation catalog not found: #{path}" unless path.file?

      values = Hash.new { |hash, key| hash[key] = Set.new }
      current_section = nil
      deprecated_values = Hash.new { |hash, key| hash[key] = Set.new }
      current_deprecated_section = nil

      path.readlines.each do |line|
        if line =~ %r{<summary>([^<]+)</summary>}
          summary = Regexp.last_match(1)
          current_section = CATALOG_SECTIONS[summary]
          current_deprecated_section = DEPRECATED_CATALOG_SECTIONS[summary]
          next
        end

        if line.start_with?('</details>')
          current_section = nil
          current_deprecated_section = nil
        end

        if current_section
          match = line.match(/^- `([^`]+)` \(\d+\)$/)
          values[current_section] << match[1] if match
        elsif current_deprecated_section
          match = line.match(/^- `([^`]+)`(?:\s|$)/)
          deprecated_values[current_deprecated_section] << match[1] if match
        end
      end

      missing_sections = CATALOG_SECTIONS.values.reject { |section| values[section].any? }
      raise "Relation catalog inventory missing sections: #{missing_sections.join(', ')}" if missing_sections.any?

      [values, deprecated_values]
    end

    def form_branches(value)
      value.to_s.split('|').map(&:strip).reject(&:empty?)
    end

    def namespace_for(form)
      form.split(':', 2).first if form.include?(':')
    end

    def allowed_namespaces(catalog_values)
      catalog_values.values.each_with_object(Set.new) do |values, namespaces|
        values.each do |value|
          form_branches(value).each do |branch|
            namespace = namespace_for(branch)
            namespaces << namespace if namespace
          end
        end
      end
    end

    def path_label(path)
      path.map(&:to_s).join('.')
    end

    def add_error(errors, file, message)
      errors << "#{file}: #{message}"
    end

    def review_relation_match(value)
      BANNED_REVIEW_RELATIONS.find { |pattern| value.to_s.match?(pattern) }
    end

    def catalog_value_reviewed?(value, catalog_entries)
      value = value.to_s
      return true if catalog_entries.include?(value)

      branches = form_branches(value)
      return false if branches.empty?

      reviewed_branches = catalog_entries.flat_map { |entry| form_branches(entry) }.to_set
      branches.all? { |branch| reviewed_branches.include?(branch) }
    end

    def hop_via_path?(path)
      path.length >= 3 && path[-3].to_s == 'hops' && path[-1].to_s == 'via'
    end

    def traverse(value, path = [], &block)
      case value
      when Hash
        value.each do |key, child|
          yield(:key, key, path + [key])
          traverse(child, path + [key], &block)
        end
      when Array
        value.each_with_index { |child, index| traverse(child, path + [index], &block) }
      else
        yield(:value, value, path)
      end
    end

    def check_catalog_value(errors, file, field, value, catalog_values, deprecated_values, namespace_set, kind)
      value = value.to_s
      return if value.empty?

      if catalog_value_reviewed?(value, deprecated_values[kind])
        add_error(errors, file, "#{field} value `#{value}` is deprecated in docs/RELATION_CATALOG.md")
        return
      end

      return if catalog_value_reviewed?(value, catalog_values[kind])

      form_branches(value).each do |branch|
        namespace = namespace_for(branch)
        if namespace.nil?
          add_error(errors, file, "#{field} value `#{branch}` has no namespace prefix")
        elsif !namespace_set.include?(namespace)
          add_error(errors, file, "#{field} value `#{branch}` uses unreviewed namespace `#{namespace}`")
        end
      end

      add_error(errors, file, "#{field} value `#{value}` is not catalog-reviewed in docs/RELATION_CATALOG.md")
    end

    def check_constraint_form(errors, file, field, value, catalog_form_values, deprecated_form_values, namespace_set)
      value = value.to_s
      return if value.empty?

      if catalog_value_reviewed?(value, deprecated_form_values)
        add_error(errors, file, "#{field} value `#{value}` is deprecated in docs/RELATION_CATALOG.md")
        return
      end

      return if catalog_value_reviewed?(value, catalog_form_values)

      form_branches(value).each do |branch|
        namespace = namespace_for(branch)
        if namespace.nil?
          add_error(errors, file, "#{field} value `#{branch}` has no namespace prefix")
        elsif !namespace_set.include?(namespace)
          add_error(errors, file, "#{field} value `#{branch}` uses unreviewed namespace `#{namespace}`")
        end
      end
    end

    def check_pattern_file(file, catalog_values, deprecated_values, namespace_set)
      errors = []
      data = YAML.safe_load(file.read, aliases: false)
      unless data.is_a?(Hash)
        add_error(errors, file, 'top-level YAML document must be a mapping')
        return errors
      end

      traverse(data) do |kind, value, path|
        if kind == :key && SIDECAR_ONLY_KEYS.include?(value.to_s)
          add_error(errors, file, "sidecar-only key `#{value}` is not allowed in pattern YAML")
        end

        next unless value.is_a?(String)

        if review_relation_match(value) && !hop_via_path?(path)
          add_error(errors, file, "`#{path_label(path)}` contains generated review-gate vocabulary `#{value}`")
        end
      end

      check_catalog_value(errors, file, 'source', data['source'], catalog_values, deprecated_values, namespace_set, :source)
      check_catalog_value(errors, file, 'target', data['target'], catalog_values, deprecated_values, namespace_set, :target)

      Array(data['hops']).each_with_index do |hop, index|
        next unless hop.is_a?(Hash)

        via = hop['via'].to_s
        if review_relation_match(via)
          add_error(errors, file, "hops[#{index}].via uses generated review-gate relation `#{via}`")
        elsif catalog_value_reviewed?(via, deprecated_values[:via])
          add_error(errors, file, "hops[#{index}].via value `#{via}` is deprecated in docs/RELATION_CATALOG.md")
        elsif !catalog_value_reviewed?(via, catalog_values[:via])
          add_error(errors, file, "hops[#{index}].via value `#{via}` is not catalog-reviewed in docs/RELATION_CATALOG.md")
        end

        check_catalog_value(errors, file, "hops[#{index}].form", hop['form'], catalog_values, deprecated_values, namespace_set, :form)
      end

      all_form_values = catalog_values[:source] | catalog_values[:target] | catalog_values[:form]
      deprecated_form_values = deprecated_values[:source] | deprecated_values[:target] | deprecated_values[:form]
      degree_caps = data.dig('constraints', 'degree_caps')
      if degree_caps.is_a?(Hash)
        degree_caps.each_key do |form|
          check_constraint_form(errors, file, 'constraints.degree_caps key', form, all_form_values, deprecated_form_values, namespace_set)
        end
      end

      Array(data.dig('constraints', 'negative_nodes')).each_with_index do |node, index|
        next unless node.is_a?(Hash)

        check_constraint_form(
          errors,
          file,
          "constraints.negative_nodes[#{index}].form",
          node['form'],
          all_form_values,
          deprecated_form_values,
          namespace_set
        )
      end

      errors
    rescue StandardError => e
      ["#{file}: YAML parse failed: #{e.message}"]
    end

    def doc_ipv4?(value)
      ip = IPAddr.new(value)
      DOC_IPV4_RANGES.any? { |range| range.include?(ip) }
    rescue ArgumentError
      false
    end

    def normalized_domain(value)
      domain = value.downcase.sub(/\Ahttps?:\/\//, '').split(/[\/:?#]/, 2).first
      domain = domain.split('@', 2).last
      domain
    end

    def special_domain?(value)
      domain = normalized_domain(value)

      SPECIAL_DOMAIN_SUFFIXES.any? do |suffix|
        domain == suffix || domain.end_with?(".#{suffix}")
      end
    end

    def sensitive_domain?(value)
      domain = normalized_domain(value)
      return false if special_domain?(domain)

      SENSITIVE_DOMAIN_TLDS.include?(domain.split('.').last)
    end

    def placeholder_hex?(value)
      hex = value.downcase
      return true if hex.match?(/\A([0-9a-f])\1+\z/)

      runs = []
      hex.scan(/([0-9a-f])\1*/) { runs << Regexp.last_match(0) }
      return true if runs.all? { |run| run.length >= 4 }

      (2..8).any? do |unit_size|
        next false unless (hex.length % unit_size).zero?

        unit = hex[0, unit_size]
        unit * (hex.length / unit_size) == hex
      end
    end

    def redacted_or_example?(value)
      value.to_s.match?(/example|synthetic|placeholder|redacted|dummy|fake/i)
    end

    def scan_fixture_line(file, line, number, errors)
      location = "#{file}:#{number}"

      if review_relation_match(line)
        add_error(errors, location, 'contains generated review-gate vocabulary')
      end

      line.scan(/\b(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}\b/) do |ip|
        next if doc_ipv4?(ip)

        add_error(errors, location, "contains non-documentation IPv4 address `#{ip}`")
      end

      line.scan(%r{\bhttps?://[^\s"'<>]+}) do |url|
        next if special_domain?(url)

        add_error(errors, location, "contains non-example URL `#{url}`")
      end

      line.scan(/\b[A-Z0-9._%+\-]+@([A-Z0-9.\-]+\.[A-Z]{2,})\b/i) do |match|
        domain = match.first
        next if special_domain?(domain)

        add_error(errors, location, "contains non-example email domain `#{domain}`")
      end

      line.scan(/\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\b/i) do |domain|
        next unless sensitive_domain?(domain)

        add_error(errors, location, "contains non-example domain `#{domain}`")
      end

      line.scan(/\b[a-f0-9]{32}\b|\b[a-f0-9]{40}\b|\b[a-f0-9]{64}\b/i) do |hex|
        next if placeholder_hex?(hex)

        add_error(errors, location, "contains plausible real hash `#{hex}`")
      end

      line.scan(/\bCVE-\d{4}-\d{4,}\b/i) do |cve|
        add_error(errors, location, "contains CVE identifier `#{cve}`")
      end

      CREDENTIAL_PATTERNS.each do |pattern, label|
        line.scan(pattern) do |match|
          value = match.is_a?(Array) ? match.first : match
          next if redacted_or_example?(value)

          add_error(errors, location, "contains #{label}")
        end
      end

      if line =~ /\b(?:password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token)\b\s*[:=]\s*["']?([^"',\s;]+)/i
        value = Regexp.last_match(1)
        add_error(errors, location, 'contains credential-shaped fixture value') unless redacted_or_example?(value)
      end

      COMMAND_PATTERNS.each do |pattern, label|
        add_error(errors, location, "contains #{label}") if line.match?(pattern)
      end
    end

    def check_fixture_file(file)
      errors = []
      file.readlines.each_with_index do |line, index|
        scan_fixture_line(file, line, index + 1, errors)
      end
      errors
    rescue StandardError => e
      ["#{file}: fixture scan failed: #{e.message}"]
    end

    def run(options)
      catalog_values, deprecated_values = load_catalog(options[:catalog_path])
      namespace_set = allowed_namespaces(catalog_values)

      pattern_files = options[:pattern_roots].flat_map { |root| collect_files(root, PATTERN_EXTENSIONS) }.uniq.sort
      fixture_files = options[:fixture_roots].flat_map { |root| collect_files(root, FIXTURE_EXTENSIONS) }
                                             .reject { |file| validator_fixture_case?(file, options[:repo_root]) }
                                             .uniq
                                             .sort

      errors = []
      pattern_files.each { |file| errors.concat(check_pattern_file(file, catalog_values, deprecated_values, namespace_set)) }
      fixture_files.each { |file| errors.concat(check_fixture_file(file)) }

      if errors.empty?
        puts "CTI promotion lint passed for #{pattern_files.length} pattern files and #{fixture_files.length} fixture files"
        return 0
      end

      puts 'CTI promotion lint failures:'
      errors.each { |message| puts "  - #{message}" }
      1
    end

    def main(argv = ARGV)
      options, parser = parse_args(argv)
      run(options)
    rescue OptionParser::ParseError => e
      warn e.message
      warn parser
      2
    rescue StandardError => e
      warn e.message
      2
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit EveryPivot::CtiPromotionLint.main(ARGV)
end
