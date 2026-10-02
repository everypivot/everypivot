#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'rbconfig'
require 'zlib'
require_relative 'package_repository_provenance'
require_relative 'utf8_text'

class PackageRepositoryProvenanceTest < Minitest::Test
  P = EveryPivot::PackageRepositoryProvenance
  ROOT = File.expand_path('..', EveryPivot::Utf8Text.decode(__dir__, path: __FILE__))
  FIXTURES = File.join(ROOT, 'fixtures/package-repository-provenance')

  def setup
    @tmp = Dir.mktmpdir('everypivot-provenance-')
    @repo = File.join(@tmp, 'repo')
    FileUtils.mkdir_p(@repo)
    git('init', '-q', '--object-format=sha1')
    File.binwrite(File.join(@repo, 'hello.txt'), "hello\n")
    git('add', '--', 'hello.txt')
    git('commit', '-qm', 'synthetic source snapshot')
    @first_commit = git('rev-parse', 'HEAD').strip
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def git(*args)
    env = ENV.keys.select { |key| key.start_with?('GIT_') }.to_h { |key| [key, nil] }
    env.merge!('GIT_CONFIG_NOSYSTEM' => '1', 'GIT_CONFIG_GLOBAL' => File::NULL,
               'GIT_AUTHOR_DATE' => '2026-08-10T12:00:00Z', 'GIT_COMMITTER_DATE' => '2026-08-10T12:00:00Z')
    out, err, status = Open3.capture3(env, 'git', '-C', @repo,
      '-c', 'user.name=EveryPivot Synthetic Fixture', '-c', 'user.email=fixture@example.invalid',
      '-c', 'commit.gpgsign=false', '-c', "core.hooksPath=#{File::NULL}", *args)
    assert status.success?, "Git fixture preparation failed: #{err}"
    out
  end

  def record(name = 'version-declaration')
    JSON.parse(EveryPivot::Utf8Text.read(File.join(FIXTURES, "#{name}.record.json")))
  end

  def bound_record(commit = @first_commit, algorithm = 'sha1')
    data = record
    data['revision_binding'] = {
      'status' => 'declared', 'package' => data['package'].dup,
      'repository_uri' => data['repository_uri'],
      'commit' => {'algorithm' => algorithm, 'id' => commit},
      'evidence' => data['declaration']['evidence'].merge('field' => '/synthetic/version_commit_binding')
    }
    data
  end

  def test_synthetic_declarations_preserve_evidence_without_a_revision
    %w[version-declaration mirror-reference].each do |name|
      data = record(name)
      assert_empty P.validate(data)
      source = File.binread(File.join(FIXTURES, "#{name}.source.json"))
      assert_equal Digest::SHA256.hexdigest(source), data.dig('declaration', 'evidence', 'sha256')
      got = P.build(data, repo_path: @repo)
      assert_equal data['declaration'], got['declaration']
      assert_equal data['package'], got['package']
      assert_equal data['revision_binding'], got['revision_binding']
      assert_equal 'unresolved', got.dig('snapshot', 'status')
      refute got['snapshot'].key?('digest')
      assert_equal 'not_verified', got['build_provenance']
    end
  end

  def test_fixed_independent_digest_vector_and_empty_tree
    vector = JSON.parse(EveryPivot::Utf8Text.read(File.join(FIXTURES, 'snapshot-v1.vector.json')))
    got = P.build(bound_record, repo_path: @repo)
    assert_equal vector['entries'], got.dig('snapshot', 'entries')
    assert_equal vector['digest'], got.dig('snapshot', 'digest')
    assert_equal vector['empty_tree_digest'], P.entries_digest([])
    assert_equal @first_commit, got.dig('snapshot', 'commit', 'id')
    assert_equal 'sha1', got.dig('snapshot', 'commit', 'algorithm')
    assert_equal 'sha256', got.dig('snapshot', 'algorithm')
    assert_equal 'evidence_only', got['evidence_mode']
    assert_equal 'not_verified', got['build_provenance']
    assert_empty P.validate(got)
  end

  def test_explicit_commit_ignores_dirty_worktree_new_head_and_commit_metadata
    original = P.build(bound_record, repo_path: @repo)
    File.binwrite(File.join(@repo, 'hello.txt'), 'changed current worktree')
    File.binwrite(File.join(@repo, 'untracked'), 'not source at selected commit')
    git('add', '--', 'hello.txt')
    git('commit', '-qm', 'newer source content')
    assert_equal original['snapshot'], P.build(bound_record, repo_path: @repo)['snapshot']
    changed = P.build(bound_record(git('rev-parse', 'HEAD').strip), repo_path: @repo)
    refute_equal original.dig('snapshot', 'digest'), changed.dig('snapshot', 'digest')
    git('commit', '--allow-empty', '-qm', 'different metadata, same tree')
    same_tree = P.build(bound_record(git('rev-parse', 'HEAD').strip), repo_path: @repo)
    assert_equal changed.dig('snapshot', 'digest'), same_tree.dig('snapshot', 'digest')
    refute_equal changed.dig('snapshot', 'commit'), same_tree.dig('snapshot', 'commit')
  end

  def test_file_mode_and_symlink_bytes_are_part_of_snapshot
    original = P.build(bound_record, repo_path: @repo)
    git('update-index', '--chmod=+x', 'hello.txt')
    git('commit', '-qm', 'executable bit')
    executable = P.build(bound_record(git('rev-parse', 'HEAD').strip), repo_path: @repo)
    refute_equal original.dig('snapshot', 'digest'), executable.dig('snapshot', 'digest')
    File.symlink('/unavailable/target', File.join(@repo, 'link'))
    git('add', '--', 'link')
    git('commit', '-qm', 'symlink source entry')
    linked = P.build(bound_record(git('rev-parse', 'HEAD').strip), repo_path: @repo)
    link = linked['snapshot']['entries'].find { |e| Base64.strict_decode64(e['path_base64']) == 'link' }
    assert_equal '120000', link['mode']
    assert_equal Digest::SHA256.hexdigest('/unavailable/target'), link['sha256']
    refute_equal executable.dig('snapshot', 'digest'), linked.dig('snapshot', 'digest')
  end

  def test_invalid_commit_ids_algorithms_and_cross_version_bindings
    %w[HEAD main v1.4.0 deadbeef].each do |bad|
      assert_raises(P::InvalidRecord) { P.build(bound_record(bad), repo_path: @repo) }
      assert_raises(P::InvalidRecord) { P.hash_snapshot(@repo, {'algorithm' => 'sha1', 'id' => bad}) }
    end
    assert_raises(P::InvalidRecord) { P.build(bound_record(@first_commit, 'sha512'), repo_path: @repo) }
    %w[version registry name].each do |field|
      data = bound_record
      data['revision_binding']['package'][field] = 'different'
      assert_raises(P::InvalidRecord) { P.build(data, repo_path: @repo) }
    end
    data = bound_record
    data['revision_binding']['repository_uri'] += '-mirror'
    assert_raises(P::InvalidRecord) { P.build(data, repo_path: @repo) }
    data = record
    data['assessment'] = {'accepted' => true}
    assert_raises(P::InvalidRecord) { P.build(data) }
    data = record
    data['contract_version'] = '99'
    assert_raises(P::InvalidRecord) { P.build(data) }
  end

  def test_local_snapshot_unavailability_is_explicit_and_does_not_erase_declaration
    [P.build(bound_record), P.build(bound_record('0' * 40), repo_path: @repo)].each do |got|
      assert_equal 'unresolved', got.dig('snapshot', 'status')
      refute got['snapshot'].key?('digest')
      assert_equal record['declaration'], got['declaration']
    end
    git('update-index', '--add', '--cacheinfo', "160000,#{@first_commit},dependency")
    git('commit', '-qm', 'unexpanded submodule')
    got = P.build(bound_record(git('rev-parse', 'HEAD').strip), repo_path: @repo)
    assert_equal 'unresolved', got.dig('snapshot', 'status')
    assert_match(/submodule/, got.dig('snapshot', 'reason'))
    refute got['snapshot'].key?('digest')
  end

  def test_lfs_pointer_does_not_become_a_source_content_hash
    File.binwrite(File.join(@repo, 'large.bin'), "version https://git-lfs.github.com/spec/v1\noid sha256:#{'1' * 64}\nsize 100000\n")
    git('add', '--', 'large.bin')
    git('commit', '-qm', 'unmaterialized LFS')
    got = P.build(bound_record(git('rev-parse', 'HEAD').strip), repo_path: @repo)
    assert_equal 'unresolved', got.dig('snapshot', 'status')
    assert_match(/LFS/, got.dig('snapshot', 'reason'))
    refute got['snapshot'].key?('digest')
  end

  def test_snapshot_self_consistency_and_acquisition_time_limits
    got = P.build(bound_record, repo_path: @repo)
    bad = Marshal.load(Marshal.dump(got))
    bad['snapshot']['digest'] = '0' * 64
    refute_empty P.validate(bad)
    bad = Marshal.load(Marshal.dump(got))
    bad['snapshot']['commit']['id'] = '0' * 40
    refute_empty P.validate(bad)
    bad = Marshal.load(Marshal.dump(got))
    bad['snapshot']['entries'] *= 2
    refute_empty P.validate(bad)
    %w[2026-02-30T00:00:00Z 2026-08-10T24:00:00Z 2026-08-10T10:00:00 2026-08-10T10:00:00-00:00 2026-08-10T10:00:00+99:99].each do |time|
      data = record
      data['declaration']['evidence']['acquired_at'] = time
      assert_raises(P::InvalidRecord) { P.build(data) }
    end
    assert_equal '2026-09-14T08:00:00Z', got.dig('declaration', 'evidence', 'acquired_at')
    refute got.key?('known_at_publication')
    data = bound_record(@first_commit + "\n")
    assert_raises(P::InvalidRecord) { P.build(data, repo_path: @repo) }
    data = record
    data['declaration']['evidence']['sha256'] += "\n"
    assert_raises(P::InvalidRecord) { P.build(data) }
  end

  def test_git_replace_objects_cannot_redirect_snapshot
    File.binwrite(File.join(@repo, 'hello.txt'), 'replacement content')
    git('add', '--', 'hello.txt')
    git('commit', '-qm', 'replacement commit')
    replacement = git('rev-parse', 'HEAD').strip
    git('replace', @first_commit, replacement)
    got = P.build(bound_record, repo_path: @repo)
    assert_equal '2b83ba6df9942b489462748a1fb2fe76dc81f4a6c13c8a2f25917233a45775e7', got.dig('snapshot', 'digest')
  end

  def test_commit_tree_and_blob_corruption_never_produce_a_bound_digest
    ids = {'commit' => @first_commit, 'tree' => git('rev-parse', "#{@first_commit}^{tree}").strip,
           'blob' => git('rev-parse', "#{@first_commit}:hello.txt").strip}
    ids.each do |type, oid|
      path = File.join(@repo, '.git', 'objects', oid[0, 2], oid[2..-1])
      original = File.binread(path)
      body = git('cat-file', type, oid).b
      # Keep parseable object framing under the original object filename.
      changed = type == 'blob' ? 'altered'.b : body.sub(type == 'commit' ? 'synthetic' : 'hello.txt', type == 'commit' ? 'different' : 'other.txt')
      refute_equal body, changed
      File.chmod(0o600, path)
      File.binwrite(path, Zlib::Deflate.deflate("#{type} #{changed.bytesize}\0".b + changed))
      got = P.build(bound_record, repo_path: @repo)
      assert_equal 'unresolved', got.dig('snapshot', 'status'), type
      refute got['snapshot'].key?('digest'), type
      assert_match(/identity verification/, got.dig('snapshot', 'reason'))
      File.binwrite(path, original)
    end
  end

  def test_sha256_git_repository_has_same_content_digest_and_distinct_object_format
    @repo = File.join(@tmp, 'repo-sha256')
    FileUtils.mkdir_p(@repo)
    git('init', '-q', '--object-format=sha256')
    File.binwrite(File.join(@repo, 'hello.txt'), "hello\n")
    git('add', '--', 'hello.txt')
    git('commit', '-qm', 'sha256 Git fixture')
    oid = git('rev-parse', 'HEAD').strip
    assert_equal 64, oid.length
    got = P.build(bound_record(oid, 'sha256'), repo_path: @repo)
    assert_equal '2b83ba6df9942b489462748a1fb2fe76dc81f4a6c13c8a2f25917233a45775e7', got.dig('snapshot', 'digest')
    assert_equal 'sha256', got.dig('snapshot', 'commit', 'algorithm')
  end

  def test_recursive_tree_paths_and_newlines_are_unambiguous
    FileUtils.mkdir_p(File.join(@repo, 'a'))
    {'a/nested.txt' => 'nested', 'a.txt' => 'sibling', "line\nname" => 'newline path'}.each do |path, contents|
      File.binwrite(File.join(@repo, path), contents)
    end
    git('add', '--all')
    git('commit', '-qm', 'nested paths')
    got = P.build(bound_record(git('rev-parse', 'HEAD').strip), repo_path: @repo)
    assert_equal 'hashed', got.dig('snapshot', 'status')
    entries = got['snapshot']['entries']
    paths = entries.map { |entry| Base64.strict_decode64(entry['path_base64']) }
    assert_equal ['a.txt', 'a/nested.txt', 'hello.txt', "line\nname"], paths
    assert_equal Digest::SHA256.hexdigest('nested'), entries[1]['sha256']
    assert_equal Digest::SHA256.hexdigest('newline path'), entries[3]['sha256']
    assert_empty P.validate(got)
  end

  def test_cli_preserves_input_and_checks_only_declared_scope
    input = File.join(@tmp, 'input.json')
    output = File.join(@tmp, 'output.json')
    raw = JSON.pretty_generate(bound_record)
    File.write(input, raw)
    command = [RbConfig.ruby, File.join(__dir__, 'package_repository_provenance.rb')]
    _, err, status = Open3.capture3(*command, '--input', input, '--repo', @repo, '--output', output)
    assert status.success?, err
    assert_equal raw.b, File.binread(input)
    got = JSON.parse(EveryPivot::Utf8Text.read(output))
    assert_equal 'hashed', got.dig('snapshot', 'status')
    text, err, status = Open3.capture3(*command, '--input', output, '--check')
    assert status.success?, err
    assert_match(/not verified/, text)
    _, _, status = Open3.capture3(*command, '--input', input, '--repo', @repo, '--output', output)
    assert_equal 2, status.exitstatus
    assert_equal got, JSON.parse(EveryPivot::Utf8Text.read(output))
  end
end
