#!/usr/bin/env ruby

# Scans every commit reachable from a git ref for secret-shaped literals.
#
# The release surface includes every commit reachable from the release ref,
# not just the current tree. A secret-shaped literal at any reachable commit
# is part of the public artifact, even if the working tree is clean. The
# canonical check is "does any commit reachable from <ref> contain a match for
# pattern <P>?"; working-tree grep is insufficient.
#
# What this tool does:
#   - Enumerates all commits reachable from <ref> (default HEAD).
#   - For each commit, runs `git grep` over the tree for each configured
#     pattern.
#   - Reports findings as `<short_sha>:<path>:<pattern_name>` lines plus a
#     summary count.
#
# What this tool does NOT do:
#   - It does not classify whether a match is a real secret. A match is a
#     surface-level alert; the maintainer decides whether it is a fake, a
#     fixture, a documentation example, or a real leak. Acceptable
#     resolutions: assemble the value at runtime, replace with a documented
#     sentinel, allow-list the case explicitly, or rotate and amend history.
#   - It does not detect novel secret formats or natural-language secrets.
#     Pair with project-specific lints and manual review.
#
# Exit codes:
#   0  no findings (or all findings allow-listed)
#   1  one or more findings outside the allow-list
#   2  invocation error (bad arguments, ref does not exist, git unavailable)

require 'json'
require 'optparse'
require 'pathname'
require 'set'

module EveryPivot
  module CheckReachableHistory
    REPO_ROOT = Pathname(__dir__).join('..').expand_path
    VERSION = '1.0.0'

    # Each pattern names the format it detects. Patterns are intentionally
    # narrow and format-locked rather than entropy-based; entropy detection
    # produces too many false positives on public corpora. Add new patterns
    # explicitly with a name and a regex; do not bake severity or confidence
    # into the tool — that judgment is downstream.
    # Patterns use POSIX ERE syntax — what `git grep -E` accepts on macOS,
    # Linux, and Windows alike. We deliberately omit `\b` word boundaries
    # (not portable across grep implementations) and non-capturing groups
    # (`(?:...)` — PCRE only). A slightly broader scope (matches inside
    # longer strings) is acceptable for a release-surface scanner.
    DEFAULT_PATTERNS = {
      'aws_access_key_id' => /AKIA[0-9A-Z]{16}/,
      'github_pat_modern' => /gh[pousr]_[A-Za-z0-9]{36}/,
      'openai_api_key' => /sk-[A-Za-z0-9]{20,}/,
      'anthropic_api_key' => /sk-ant-[-A-Za-z0-9_]{20,}/,
      'slack_token' => /xox[abprs]-[-0-9A-Za-z]{10,48}/,
      'private_key_rsa' => /-----BEGIN RSA PRIVATE KEY-----/,
      'private_key_openssh' => /-----BEGIN OPENSSH PRIVATE KEY-----/,
      'private_key_pem' => /-----BEGIN (EC |DSA |ENCRYPTED )?PRIVATE KEY-----/,
      'private_key_pgp' => /-----BEGIN PGP PRIVATE KEY BLOCK-----/
    }.freeze

    # The allow-list lets a project mark known-safe matches that should not
    # fail the gate. Entries are matched against
    # "<short_sha>:<path>:<pattern_name>" lines.
    #
    # An allow-list entry can be:
    #   - a literal string match against the full line
    #   - a glob using shell-style wildcards (* matches any chars)
    #
    # The recommended file format is one entry per line, with `#` comments
    # and blank lines ignored.
    module_function

    def discover_commits(ref:, repo_root: REPO_ROOT)
      stdout, status = run_git(repo_root, 'rev-list', ref)
      raise InvocationError, "git rev-list #{ref} failed" unless status.success?
      stdout.split("\n").reject(&:empty?)
    end

    def grep_commit_for_pattern(commit_sha:, pattern_name:, regex:, repo_root: REPO_ROOT)
      # `git grep -EI` runs an extended-regex search over the named tree.
      # -I skips binary blobs (we do not scan them); -E enables ERE syntax.
      # -e fences the pattern so leading `-` characters (PEM block headers)
      # are not parsed as flags. The exit codes are 0 = matches,
      # 1 = no matches, >=2 = error.
      stdout, status = run_git(repo_root, 'grep', '-EIn', '-e', regex.source, commit_sha)
      case status.exitstatus
      when 0
        parse_grep_output(stdout, commit_sha: commit_sha, pattern_name: pattern_name)
      when 1
        []
      else
        raise InvocationError, "git grep failed for commit #{commit_sha}, pattern #{pattern_name}"
      end
    end

    def parse_grep_output(stdout, commit_sha:, pattern_name:)
      stdout.split("\n").each_with_object([]) do |line, findings|
        # `git grep <sha>` prefixes each match with "<sha>:<path>:<lineno>:<content>"
        next if line.empty?
        prefix, _, _ = line.partition(':')
        next unless prefix == commit_sha
        remainder = line[(commit_sha.length + 1)..]
        next unless remainder
        path, _, after_path = remainder.partition(':')
        lineno, _, content = after_path.partition(':')
        findings << {
          'commit' => commit_sha,
          'short_sha' => commit_sha[0, 12],
          'path' => path,
          'lineno' => lineno.to_i,
          'pattern_name' => pattern_name,
          'content_excerpt' => excerpt(content)
        }
      end
    end

    def excerpt(content)
      stripped = content.to_s.strip
      stripped.length > 200 ? "#{stripped[0, 197]}..." : stripped
    end

    def load_allow_list(path)
      return [] unless path && File.exist?(path)
      File.read(path).each_line.map do |raw|
        line = raw.strip
        next nil if line.empty? || line.start_with?('#')
        line
      end.compact
    end

    def finding_signature(finding)
      "#{finding['short_sha']}:#{finding['path']}:#{finding['pattern_name']}"
    end

    def matches_allow_entry?(signature, entry)
      return true if signature == entry
      pattern = '^' + Regexp.escape(entry).gsub('\\*', '.*') + '$'
      !!signature.match?(Regexp.new(pattern))
    end

    def allow_listed?(finding, allow_entries)
      signature = finding_signature(finding)
      allow_entries.any? { |entry| matches_allow_entry?(signature, entry) }
    end

    def run_git(repo_root, *args)
      require 'open3'
      Open3.capture2('git', '-C', repo_root.to_s, *args)
    rescue Errno::ENOENT
      raise InvocationError, 'git executable not found on PATH'
    end

    def scan(ref:, repo_root: REPO_ROOT, patterns: DEFAULT_PATTERNS, allow_entries: [])
      commits = discover_commits(ref: ref, repo_root: repo_root)
      findings = []
      commits.each do |sha|
        patterns.each do |name, regex|
          findings.concat(grep_commit_for_pattern(
            commit_sha: sha,
            pattern_name: name,
            regex: regex,
            repo_root: repo_root
          ))
        end
      end
      partition_findings(findings, allow_entries: allow_entries)
    end

    def partition_findings(findings, allow_entries:)
      blocking = []
      allow_listed = []
      findings.each do |f|
        if allow_listed?(f, allow_entries)
          allow_listed << f
        else
          blocking << f
        end
      end
      { 'blocking' => blocking, 'allow_listed' => allow_listed }
    end

    def parse_args(argv)
      options = {
        ref: 'HEAD',
        repo_root: REPO_ROOT,
        allow_list_path: REPO_ROOT.join('.reachable-history-allowlist'),
        patterns_file: nil,
        format: 'text'
      }

      parser = OptionParser.new do |opt|
        opt.banner = 'Usage: check_reachable_history.rb [options]'
        opt.on('--ref REF', 'Git ref to scan (default HEAD)') { |v| options[:ref] = v }
        opt.on('--repo-root PATH', 'Repository root (default project root)') do |v|
          options[:repo_root] = Pathname(v).expand_path
        end
        opt.on('--allow-list PATH', 'Path to allow-list file') do |v|
          options[:allow_list_path] = Pathname(v).expand_path
        end
        opt.on('--patterns-file PATH', 'JSON file overriding default patterns') do |v|
          options[:patterns_file] = Pathname(v).expand_path
        end
        opt.on('--format FMT', %w[text json], 'Output format: text (default) or json') do |v|
          options[:format] = v
        end
        opt.on('--version', 'Print tool version and exit') do
          puts VERSION
          exit 0
        end
      end

      parser.parse!(argv)
      options
    end

    def load_patterns(path)
      return DEFAULT_PATTERNS unless path
      raise InvocationError, "patterns file not found: #{path}" unless File.exist?(path)
      data = JSON.parse(File.read(path))
      data.each_with_object({}) do |(name, regex_source), patterns|
        patterns[name] = Regexp.new(regex_source)
      end
    end

    def render_text(result)
      blocking = result['blocking']
      allow_listed = result['allow_listed']

      if blocking.empty? && allow_listed.empty?
        puts 'No secret-shaped literals found in reachable history.'
        return
      end

      blocking.each { |f| puts "BLOCKING  #{finding_signature(f)}  L#{f['lineno']}: #{f['content_excerpt']}" }
      allow_listed.each { |f| puts "allow     #{finding_signature(f)}  L#{f['lineno']}: #{f['content_excerpt']}" }

      puts ''
      puts "Summary: #{blocking.size} blocking, #{allow_listed.size} allow-listed"
    end

    def render_json(result)
      puts JSON.pretty_generate(result)
    end

    def main(argv = ARGV)
      options = parse_args(argv)
      patterns = load_patterns(options[:patterns_file])
      allow_entries = load_allow_list(options[:allow_list_path])
      result = scan(
        ref: options[:ref],
        repo_root: options[:repo_root],
        patterns: patterns,
        allow_entries: allow_entries
      )

      case options[:format]
      when 'json'
        render_json(result)
      else
        render_text(result)
      end

      result['blocking'].empty? ? 0 : 1
    rescue InvocationError => e
      warn "check_reachable_history.rb: #{e.message}"
      2
    end

    class InvocationError < StandardError; end
  end
end

if $PROGRAM_NAME == __FILE__
  exit EveryPivot::CheckReachableHistory.main(ARGV)
end
