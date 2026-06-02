#!/usr/bin/env ruby

# Tests for check_reachable_history.rb covering boundary roles a fixture
# suite for this kind of scanner should hit (fixtures should test
# boundaries, not just happy paths):
#
#   - positive case: planted secret-shaped literal is detected
#   - negative control: clean tree produces no findings
#   - suppression: allow-list entry suppresses a known case
#   - high-cardinality: many literals across many commits all reported
#   - parser edge cases: binary files skipped; deleted files still scanned
#     at the commit where they existed; patterns starting with `-` accepted
#   - blocked assertions: not a real-secret classifier, just a shape detector
#
# The tests build a disposable git repository in a tmpdir and run the
# check tool against it via Open3.

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'tmpdir'

class CheckReachableHistoryTest < Minitest::Test
  TOOL = Pathname(__dir__).join('check_reachable_history.rb').expand_path
  AKIA_LITERAL = 'AKIA' + 'ABCDEFGHIJKLMNOP'
  GITHUB_PAT_LITERAL = 'ghp_' + ('A' * 36)
  RSA_HEADER = '-----BEGIN RSA PRIVATE KEY-----'

  def setup
    @tmpdir = Pathname(Dir.mktmpdir('check-reachable-history-'))
    git(@tmpdir, 'init', '-q', '-b', 'main')
    git(@tmpdir, 'config', 'user.email', 'test@example.com')
    git(@tmpdir, 'config', 'user.name', 'Test User')
    git(@tmpdir, 'config', 'commit.gpgsign', 'false')
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && @tmpdir.exist?
  end

  # ---- positive ----

  def test_detects_aws_access_key_in_reachable_history
    write_and_commit('fixture.json', %({"aws_key": "#{AKIA_LITERAL}"}), 'add fixture')
    result, status = run_tool('--format', 'json')
    refute status.success?, 'expected non-zero exit'
    json = JSON.parse(result)
    assert_equal 1, json['blocking'].size
    finding = json['blocking'].first
    assert_equal 'aws_access_key_id', finding['pattern_name']
    assert_equal 'fixture.json', finding['path']
  end

  def test_detects_pem_private_key_header
    write_and_commit('id.pem', "#{RSA_HEADER}\nMIIB...\n-----END RSA PRIVATE KEY-----\n", 'add pem')
    result, status = run_tool('--format', 'json')
    refute status.success?
    json = JSON.parse(result)
    refute json['blocking'].empty?
    pattern_names = json['blocking'].map { |f| f['pattern_name'] }.uniq
    assert_includes pattern_names, 'private_key_rsa'
  end

  def test_detects_github_pat
    write_and_commit('config.txt', "token=#{GITHUB_PAT_LITERAL}\n", 'add token')
    result, status = run_tool('--format', 'json')
    refute status.success?
    json = JSON.parse(result)
    assert_equal 1, json['blocking'].size
    assert_equal 'github_pat_modern', json['blocking'].first['pattern_name']
  end

  # ---- negative control ----

  def test_clean_tree_passes
    write_and_commit('readme.md', "# Just a readme.\n", 'add readme')
    result, status = run_tool('--format', 'json')
    assert status.success?, "expected exit 0, got #{status.exitstatus}: #{result}"
    json = JSON.parse(result)
    assert_empty json['blocking']
    assert_empty json['allow_listed']
  end

  # ---- suppression via allow-list ----

  def test_allow_list_suppresses_known_finding
    write_and_commit('fixture.json', %({"aws_key": "#{AKIA_LITERAL}"}), 'add fixture')
    sha = git(@tmpdir, 'rev-parse', 'HEAD').strip[0, 12]
    allow_list = @tmpdir.join('.allowlist')
    allow_list.write("#{sha}:fixture.json:aws_access_key_id\n")
    result, status = run_tool('--allow-list', allow_list.to_s, '--format', 'json')
    assert status.success?, "expected exit 0 after allow-list, got #{status.exitstatus}"
    json = JSON.parse(result)
    assert_empty json['blocking']
    assert_equal 1, json['allow_listed'].size
  end

  def test_allow_list_glob_works
    write_and_commit('fixture.json', %({"aws_key": "#{AKIA_LITERAL}"}), 'add fixture')
    allow_list = @tmpdir.join('.allowlist')
    allow_list.write("*:fixture.json:aws_access_key_id\n")
    _result, status = run_tool('--allow-list', allow_list.to_s)
    assert status.success?
  end

  def test_allow_list_does_not_suppress_other_findings
    write_and_commit('fixture.json', %({"aws_key": "#{AKIA_LITERAL}"}), 'add aws')
    write_and_commit('config.txt', "token=#{GITHUB_PAT_LITERAL}\n", 'add pat')
    allow_list = @tmpdir.join('.allowlist')
    allow_list.write("*:fixture.json:aws_access_key_id\n")
    result, status = run_tool('--allow-list', allow_list.to_s, '--format', 'json')
    refute status.success?
    json = JSON.parse(result)
    assert_equal 1, json['blocking'].size
    assert_equal 'github_pat_modern', json['blocking'].first['pattern_name']
  end

  def test_allow_list_handles_comments_and_blank_lines
    write_and_commit('fixture.json', %({"aws_key": "#{AKIA_LITERAL}"}), 'add fixture')
    allow_list = @tmpdir.join('.allowlist')
    allow_list.write("# this is a comment\n\n*:fixture.json:aws_access_key_id\n\n# another\n")
    _result, status = run_tool('--allow-list', allow_list.to_s)
    assert status.success?
  end

  # ---- high-cardinality ----

  def test_many_findings_all_reported
    write_and_commit('a.json', %({"k": "#{AKIA_LITERAL}"}), 'a')
    write_and_commit('b.json', %({"k": "#{AKIA_LITERAL}"}), 'b')
    write_and_commit('c.json', %({"k": "#{AKIA_LITERAL}"}), 'c')
    result, status = run_tool('--format', 'json')
    refute status.success?
    json = JSON.parse(result)
    # Each commit's tree contains the file from that commit AND all prior
    # commits (git stores the full tree per commit). The check scans every
    # blob in every reachable tree, so the count is 1+2+3 = 6.
    assert_equal 6, json['blocking'].size
  end

  # ---- parser edge cases ----

  def test_binary_files_skipped
    # Build a "binary" blob with NUL bytes — git grep -I should skip it.
    binary_content = "\x00\x01\x02#{AKIA_LITERAL}\x00\x03\x04"
    path = @tmpdir.join('payload.bin')
    path.binwrite(binary_content)
    git(@tmpdir, 'add', 'payload.bin')
    git(@tmpdir, 'commit', '-q', '-m', 'add binary')
    _result, status = run_tool
    assert status.success?, 'binary file should be skipped'
  end

  def test_pattern_starting_with_dash_accepted
    # PEM headers begin with `-----`. The tool must use `-e <pattern>` so
    # the regex is not parsed as a flag.
    write_and_commit('pem.txt', "#{RSA_HEADER}\n", 'add pem')
    _result, status = run_tool('--format', 'json')
    refute status.success?, 'PEM header should match'
  end

  def test_deleted_file_still_scanned_at_commit_where_it_existed
    write_and_commit('leak.json', %({"aws_key": "#{AKIA_LITERAL}"}), 'add leak')
    leaky_sha = git(@tmpdir, 'rev-parse', 'HEAD').strip
    git(@tmpdir, 'rm', '-q', 'leak.json')
    git(@tmpdir, 'commit', '-q', '-m', 'remove leak')
    # HEAD no longer contains the file, but the commit that introduced it
    # is still reachable, so the literal is still in the release surface.
    result, status = run_tool('--format', 'json')
    refute status.success?, 'deleted file in reachable history should still trigger'
    json = JSON.parse(result)
    assert json['blocking'].any? { |f| f['commit'] == leaky_sha },
           "expected a finding at the deletion-predecessor commit #{leaky_sha}"
  end

  def test_specific_ref_scoping
    # Plant the literal on a branch, then verify HEAD on main is clean.
    write_and_commit('readme.md', "# clean\n", 'init main')
    git(@tmpdir, 'checkout', '-q', '-b', 'leaky')
    write_and_commit('leak.json', %({"aws_key": "#{AKIA_LITERAL}"}), 'add leak on branch')
    git(@tmpdir, 'checkout', '-q', 'main')

    _result, main_status = run_tool('--ref', 'main')
    assert main_status.success?, 'main should be clean'

    _result, leaky_status = run_tool('--ref', 'leaky')
    refute leaky_status.success?, 'leaky branch should report'
  end

  # ---- custom patterns file ----

  def test_custom_patterns_override
    write_and_commit('cfg.txt', "INTERNAL_TOKEN=abcdef\n", 'add internal token')
    patterns_file = @tmpdir.join('.patterns.json')
    # POSIX ERE has no `\w`; use an explicit character class.
    patterns_file.write(JSON.pretty_generate('internal_token' => 'INTERNAL_TOKEN=[A-Za-z0-9_]+'))
    result, status = run_tool('--patterns-file', patterns_file.to_s, '--format', 'json')
    refute status.success?
    json = JSON.parse(result)
    assert_equal 'internal_token', json['blocking'].first['pattern_name']
  end

  private

  def run_tool(*extra_args)
    stdout, status = Open3.capture2('ruby', TOOL.to_s, '--repo-root', @tmpdir.to_s, *extra_args)
    [stdout, status]
  end

  def write_and_commit(relative_path, content, message)
    path = @tmpdir.join(relative_path)
    path.dirname.mkpath
    path.write(content)
    git(@tmpdir, 'add', relative_path)
    git(@tmpdir, 'commit', '-q', '-m', message)
  end

  def git(repo, *args)
    stdout, status = Open3.capture2('git', '-C', repo.to_s, *args)
    raise "git #{args.join(' ')} failed: #{stdout}" unless status.success?
    stdout
  end
end
