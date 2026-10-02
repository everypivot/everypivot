#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'optparse'
require_relative 'utf8_text'
require_relative 'semantic_evaluator'
require_relative 'semantic_amendments'
require_relative 'json_schema_validator'

# Explicit local inputs only: this runner does not fetch sources, query a native
# backend, accept an assessment, write files or substitute current timestamps.
options = {sources: {}, root: File.expand_path('..', __dir__)}
parser = OptionParser.new do |p|
  p.banner = 'Usage: evaluate_semantic_pattern.rb (--pattern YAML | --contract JSON) --evidence JSON --query JSON [--source ID=PATH]'
  p.on('--pattern PATH', 'Authoring v1.6 pattern and its exact referenced contract') { |v| options[:pattern] = v }
  p.on('--contract PATH', 'Explicit standalone semantic contract, e.g. a synthetic case') { |v| options[:contract] = v }
  p.on('--root PATH', 'Package root for digest-bound pattern references') { |v| options[:root] = File.expand_path(v) }
  p.on('--evidence PATH', 'Normalized, revision-specific evidence records') { |v| options[:evidence] = v }
  p.on('--query PATH', 'Explicit scope, parameters and resource budgets') { |v| options[:query] = v }
  p.on('--source ID=PATH', 'Preserved content or history bytes; repeat for multiple sources') do |v|
    id, path = v.split('=', 2)
    raise OptionParser::InvalidArgument, '--source requires a unique ID and local path' if id.to_s.empty? || path.to_s.empty? || options[:sources].key?(id)
    options[:sources][id] = path
  end
end

def read_semantic_json(path)
  EveryPivot::SemanticContract.parse(EveryPivot::Utf8Text.read(path))
end

begin
  parser.parse!
  raise OptionParser::InvalidArgument, 'unexpected positional arguments' unless ARGV.empty?
  raise OptionParser::MissingArgument, 'exactly one of --pattern/--contract' unless [options[:pattern], options[:contract]].compact.size == 1
  %i[evidence query].each { |key| raise OptionParser::MissingArgument, "--#{key}" unless options[key] }
  if options[:pattern]
    pattern = YAML.safe_load(EveryPivot::Utf8Text.read(options[:pattern]), aliases: false)
    schema = read_semantic_json(File.join(options[:root], 'schemas/pivot_pattern.schema.json'))
    errors = EveryPivot::JsonSchemaValidator.new(schema).validate(pattern)
    raise EveryPivot::SemanticContract::InvalidContract, errors.join('; ') unless errors.empty?
    unless pattern['pattern_schema_version'].to_s == '1.6'
      raise EveryPivot::SemanticContract::UnsupportedContract, 'explicit semantic execution requires authoring v1.6; no legacy fallback'
    end
    contract = EveryPivot::SemanticContract.load_reference(pattern['execution'], pattern, root: options[:root])
    exact_source_digest = pattern['execution']['sha256']
  else
    contract = EveryPivot::SemanticContract.compile(read_semantic_json(options[:contract]))
    exact_source_digest = Digest::SHA256.file(options[:contract]).hexdigest
  end
  evidence = read_semantic_json(options[:evidence])
  query = read_semantic_json(options[:query])
  source_bytes = options[:sources].transform_values { |path| File.binread(path) }
  result = EveryPivot::SemanticEvaluator.new(contract).evaluate(evidence, query, preserved_source_bytes: source_bytes)
  result['contract_source'] = {'algorithm' => 'sha256', 'scope' => 'exact_source_bytes', 'value' => exact_source_digest}
  result['contract_hash_scope'] = 'canonical_json_v1'
  puts JSON.pretty_generate(result)
  exit(result['status'] == 'partial' ? 4 : 0)
rescue EveryPivot::SemanticContract::UnsupportedContract, EveryPivot::SemanticEvaluator::UnsupportedInput => e
  puts JSON.pretty_generate('status' => 'unsupported', 'errors' => [e.message], 'results' => [], 'assessment_acceptance' => 'not_evaluated')
  exit 3
rescue OptionParser::ParseError, SystemCallError, JSON::ParserError, Psych::Exception,
       EveryPivot::Utf8Text::Error, EveryPivot::SemanticContract::InvalidContract,
       EveryPivot::SemanticRecords::InvalidInput, EveryPivot::SemanticEvaluator::InvalidInput,
       EveryPivot::SemanticIdentity::InvalidInput, EveryPivot::SemanticTime::InvalidInput,
       EveryPivot::SemanticFinding::InvalidInput, EveryPivot::SemanticAmendments::InvalidInput,
       EveryPivot::SemanticResultPrimitives::InvalidInput, EveryPivot::SemanticPackageRepository::InvalidInput,
       EveryPivot::SemanticCertificateProfiles::InvalidInput => e
  puts JSON.pretty_generate('status' => 'invalid_input', 'errors' => [e.message], 'results' => [], 'assessment_acceptance' => 'not_evaluated')
  exit 2
end
