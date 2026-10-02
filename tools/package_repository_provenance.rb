#!/usr/bin/env ruby
# frozen_string_literal: true

require 'base64'
require 'date'
require 'digest'
require 'json'
require 'open3'
require 'optparse'
require 'pathname'
require 'time'
require_relative 'json_schema_validator'
require_relative 'utf8_text'

module EveryPivot
  # Checks supplied evidence records and hashes local, explicitly identified Git
  # trees. Neither a valid record nor a matching digest verifies a source claim,
  # package build, repository ownership, or assessment.
  module PackageRepositoryProvenance
    SCHEMA = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: __FILE__)).join('../schemas/package_repository_provenance.v1.schema.json').freeze
    METHOD = 'everypivot.git-tree-content.v1'.freeze
    DOMAIN = "EveryPivot source snapshot v1\n".b.freeze
    MODES = %w[100644 100755 120000].freeze
    class InvalidRecord < StandardError; end
    class SnapshotUnavailable < StandardError; end
    module_function

    def entries_digest(entries)
      digest = Digest::SHA256.new
      digest.update(DOMAIN)
      entries.each do |entry|
        path = Base64.strict_decode64(entry.fetch('path_base64'))
        digest.update(entry.fetch('mode') + "\0")
        digest.update(path.bytesize.to_s + "\0")
        digest.update(path)
        digest.update("\0" + entry.fetch('size').to_i.to_s + "\0")
        digest.update(entry.fetch('sha256') + "\n")
      end
      digest.hexdigest
    end

    def valid_time?(value)
      # DateTime checks calendar validity; Time can normalize impossible dates.
      return false unless value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})\z/)
      return false if value.end_with?('-00:00')
      hour, minute, second = value.split('T', 2).last[0, 8].split(':').map(&:to_i)
      return false unless hour < 24 && minute < 60 && second < 60
      if value[-1] != 'Z'
        zone_hour, zone_minute = value[-5, 5].split(':').map(&:to_i)
        return false unless zone_hour < 24 && zone_minute < 60
      end

      DateTime.iso8601(value)
      true
    rescue ArgumentError
      false
    end

    def read_json(path)
      JSON.parse(Utf8Text.read(path))
    rescue JSON::ParserError => e
      raise InvalidRecord, "Invalid JSON in #{path}: #{e.message}"
    end

    def validate(record)
      schema = read_json(SCHEMA)
      errors = JsonSchemaValidator.new(schema).validate(record)
      return errors unless errors.empty?

      anchors = [record.dig('declaration', 'evidence')]
      binding = record['revision_binding']
      if binding['status'] == 'declared'
        errors << 'revision binding package does not match the declared package version' unless binding['package'] == record['package']
        errors << 'revision binding repository does not match the declared repository' unless binding['repository_uri'] == record['repository_uri']
        anchors << binding['evidence']
      end
      anchors.each do |anchor|
        errors << 'evidence acquired_at is not a valid offset-qualified calendar timestamp' unless valid_time?(anchor['acquired_at'])
        errors << 'evidence sha256 must be exactly 64 lowercase hexadecimal characters' unless anchor['sha256'].match?(/\A[0-9a-f]{64}\z/)
        if anchor['revision'].start_with?('sha256:') && anchor['revision'] != 'sha256:' + anchor['sha256']
          errors << 'content-addressed evidence revision does not match its document digest'
        end
      end
      if binding['status'] == 'declared' && !valid_commit?(binding['commit'])
        errors << 'revision binding requires an exact full Git object ID and supported algorithm'
      end

      snapshot = record['snapshot']
      if snapshot['status'] == 'hashed'
        errors << 'a hashed snapshot requires a declared exact revision binding' unless binding['status'] == 'declared'
        errors << 'snapshot commit does not match the revision binding' unless snapshot['commit'] == binding['commit']
        errors << 'snapshot digest must be exactly 64 lowercase hexadecimal characters' unless snapshot['digest'].match?(/\A[0-9a-f]{64}\z/)
        paths = []
        snapshot['entries'].each do |entry|
          begin
            path = Base64.strict_decode64(entry['path_base64'])
            errors << 'snapshot path_base64 is not canonical base64' unless Base64.strict_encode64(path) == entry['path_base64']
            invalid = path.empty? || path.start_with?('/') || path.include?("\0") ||
                      path.split('/', -1).any? { |part| ['', '.', '..'].include?(part) }
            errors << 'snapshot paths must be nonempty relative Git paths without dot segments' if invalid
            paths << path
          rescue ArgumentError
            errors << 'snapshot path_base64 is not canonical base64'
          end
          errors << 'snapshot entry size must be nonnegative' if entry['size'] < 0
          errors << 'snapshot entry sha256 must be exactly 64 lowercase hexadecimal characters' unless entry['sha256'].match?(/\A[0-9a-f]{64}\z/)
        end
        errors << 'snapshot paths must be unique and sorted by raw bytes' unless paths == paths.uniq.sort
        if errors.empty? && entries_digest(snapshot['entries']) != snapshot['digest']
          errors << 'snapshot digest does not match its content manifest'
        end
      end
      errors
    end

    def git(repo_path, *args)
      # Replacement objects and inherited Git routing must not redirect an
      # explicitly supplied object ID to different content. No network access.
      env = ENV.keys.select { |key| key.start_with?('GIT_') }.to_h { |key| [key, nil] }
      env['GIT_CONFIG_NOSYSTEM'] = '1'
      env['GIT_CONFIG_GLOBAL'] = File::NULL
      env['GIT_ALLOW_PROTOCOL'] = ''
      env['GIT_NO_LAZY_FETCH'] = '1'
      env['GIT_TERMINAL_PROMPT'] = '0'
      stdout, _stderr, status = Open3.capture3(env, 'git', '--no-replace-objects', '-C', repo_path.to_s, *args)
      raise SnapshotUnavailable, 'requested Git object or repository is unavailable locally' unless status.success?

      stdout.b
    rescue Errno::ENOENT
      raise SnapshotUnavailable, 'Git is unavailable'
    end

    def valid_commit?(commit)
      return false unless commit.is_a?(Hash) && commit.keys.sort == %w[algorithm id]

      length = {'sha1' => 40, 'sha256' => 64}[commit['algorithm']]
      length && commit['id'].is_a?(String) && commit['id'].match?(/\A[0-9a-f]{#{length}}\z/)
    end

    def hash_snapshot(repo_path, commit)
      raise InvalidRecord, 'snapshot requires an explicit full Git commit ID and algorithm' unless valid_commit?(commit)

      algorithm = git(repo_path, 'rev-parse', '--show-object-format').strip
      raise SnapshotUnavailable, 'Git object format does not match the declared commit algorithm' unless algorithm == commit['algorithm']

      oid = commit['id']
      raise SnapshotUnavailable, 'declared object is not an available commit' unless git(repo_path, 'cat-file', '-t', oid).strip == 'commit'
      commit_bytes = verified_object(repo_path, 'commit', oid, algorithm)
      tree_match = commit_bytes.match(/\Atree ([0-9a-f]{#{oid.length}})\n/)
      raise SnapshotUnavailable, 'selected commit has no valid root tree identity' unless tree_match

      entries = []
      pending = [[tree_match[1], ''.b]]
      paths = {}
      until pending.empty?
        tree_id, prefix = pending.pop
        tree = verified_object(repo_path, 'tree', tree_id, algorithm)
        offset = 0
        while offset < tree.bytesize
          space = tree.index(' ', offset)
          nul = space && tree.index("\0", space + 1)
          object_end = nul && nul + 1 + oid.length / 2
          raise SnapshotUnavailable, 'malformed Git tree entry' unless object_end && object_end <= tree.bytesize

          mode = tree[offset...space]
          name = tree[(space + 1)...nul]
          object_id = tree[(nul + 1)...object_end].unpack1('H*')
          offset = object_end
          if name.empty? || name.include?('/') || %w[. ..].include?(name)
            raise SnapshotUnavailable, 'invalid path component in Git tree'
          end
          path = prefix + name
          raise SnapshotUnavailable, 'duplicate path in Git tree' if paths[path]

          paths[path] = true
          if mode == '40000'
            pending << [object_id, path + '/']
            next
          end
          raise SnapshotUnavailable, 'submodule content is unresolved; gitlink-only snapshots are unsupported' if mode == '160000'
          raise SnapshotUnavailable, 'unsupported Git tree entry' unless MODES.include?(mode)

          contents = verified_object(repo_path, 'blob', object_id, algorithm)
          if mode != '120000' && contents.lines.first.to_s.strip == 'version https://git-lfs.github.com/spec/v1'
            raise SnapshotUnavailable, 'Git LFS content is unresolved; pointer-only snapshots are unsupported'
          end
          entries << {
            'path_base64' => Base64.strict_encode64(path),
            'mode' => mode,
            'size' => contents.bytesize,
            'sha256' => Digest::SHA256.hexdigest(contents)
          }
        end
      end
      entries.sort_by! { |entry| Base64.strict_decode64(entry['path_base64']) }
      {
        'status' => 'hashed', 'method' => METHOD, 'algorithm' => 'sha256',
        'digest' => entries_digest(entries), 'commit' => commit.dup, 'entries' => entries
      }
    end

    def verified_object(repo_path, type, oid, algorithm)
      contents = git(repo_path, 'cat-file', type, oid)
      framed = "#{type} #{contents.bytesize}\0".b + contents
      actual = (algorithm == 'sha1' ? Digest::SHA1 : Digest::SHA256).hexdigest(framed)
      raise SnapshotUnavailable, "Git #{type} object failed content identity verification" unless actual == oid

      contents
    end

    def build(record, repo_path: nil)
      # Input may be a declaration without a computed snapshot. Discard any
      # supplied snapshot claim and recompute, or explicitly remain unresolved.
      result = Marshal.load(Marshal.dump(record))
      raise InvalidRecord, 'record must be an object' unless result.is_a?(Hash)

      result['snapshot'] = {'status' => 'unresolved', 'reason' => 'snapshot has not been computed'}
      errors = validate(result)
      raise InvalidRecord, errors.join('; ') unless errors.empty?

      binding = result['revision_binding']
      if binding['status'] != 'declared'
        result['snapshot']['reason'] = 'exact package-version source revision is unresolved: ' + binding['reason']
      elsif repo_path.nil?
        result['snapshot']['reason'] = 'local repository not supplied; exact source snapshot is unresolved'
      else
        begin
          result['snapshot'] = hash_snapshot(repo_path, binding['commit'])
        rescue SnapshotUnavailable => e
          result['snapshot'] = {'status' => 'unresolved', 'reason' => e.message}
        end
      end
      errors = validate(result)
      raise InvalidRecord, errors.join('; ') unless errors.empty?

      result
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: package_repository_provenance.rb --input RECORD.json [--repo LOCAL_REPOSITORY] [--output PATH] [--check]'
    opts.on('--input PATH', 'Supplied version-specific declaration and revision-binding evidence') { |v| options[:input] = v }
    opts.on('--repo PATH', 'Local Git repository; requires an explicit full commit ID in the evidence record') { |v| options[:repo] = v }
    opts.on('--output PATH', 'Write a new provenance record (default: stdout; existing files are not overwritten)') { |v| options[:output] = v }
    opts.on('--check', 'Validate supplied shape/self-consistency only; does not verify external evidence or Git content') { options[:check] = true }
  end
  begin
    parser.parse!
    raise OptionParser::MissingArgument, '--input' unless options[:input]
    raise OptionParser::InvalidArgument, 'unexpected positional arguments' unless ARGV.empty?
    if options[:check] && (options[:repo] || options[:output])
      raise OptionParser::InvalidArgument, '--check cannot be combined with --repo or --output'
    end
    record = EveryPivot::PackageRepositoryProvenance.read_json(options[:input])
    if options[:check]
      errors = EveryPivot::PackageRepositoryProvenance.validate(record)
      raise EveryPivot::PackageRepositoryProvenance::InvalidRecord, errors.join('; ') unless errors.empty?

      puts 'Record shape and self-consistency valid; external evidence, source content and build provenance are not verified.'
    else
      result = EveryPivot::PackageRepositoryProvenance.build(record, repo_path: options[:repo])
      output = JSON.pretty_generate(result) + "\n"
      if options[:output]
        File.open(options[:output], File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(output) }
      else
        puts output
      end
    end
  rescue OptionParser::ParseError, JSON::ParserError, EveryPivot::Utf8Text::Error, EveryPivot::PackageRepositoryProvenance::InvalidRecord, SystemCallError => e
    warn "Invalid provenance request: #{e.message}"
    exit 2
  end
end
