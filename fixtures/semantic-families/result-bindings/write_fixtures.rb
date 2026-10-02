#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require_relative 'fixture_factory'
f = ResultBindingFixtures
# These oracles are chosen from the accepted question, not obtained from an
# evaluator run. Adversarial mutations live in test_semantic_result_bindings.rb.
cases = {
  'phase-mismatch' => [f.phase, {'forms' => ['risk:observation'], 'comparison_outcomes' => ['mismatch']}],
  'phase-contested' => [f.phase(outcome: 'contested'), {'forms' => ['evidence:phase_comparison'], 'comparison_outcomes' => %w[compatible contested]}],
  'officer-direct' => [f.officer, {'forms' => ['org:org'], 'bound_ids' => %w[A B]}],
  'creative-reference' => [f.creative, {'forms' => ['inet:url'], 'bound_ids' => ['url'], 'finding_kinds' => ['URI reference']}],
  'creative-request' => [f.creative(path: 'script', kind: 'request'), {'forms' => ['inet:url'], 'bound_ids' => ['url'], 'finding_kinds' => ['creative-associated request']}],
  'kit-archive' => [f.phishkit, {'forms' => ['inet:fqdn'], 'bound_ids' => ['infrastructure'], 'match_reasons' => ['archive']}],
  'kit-file-set' => [f.phishkit(match: 'file_set'), {'forms' => ['inet:fqdn'], 'bound_ids' => ['infrastructure'], 'match_reasons' => ['file_set']}],
  'kit-shared-paths' => [f.phishkit(match: 'paths'), {'forms' => ['inet:fqdn'], 'bound_ids' => ['infrastructure'], 'match_reasons' => ['paths']}],
  'listing-ip' => [f.sbl('ip'), {'forms' => ['reputation:assertion'], 'bound_ids' => ['claim']}],
  'listing-covering-prefix' => [f.sbl('ip', covering: true), {'forms' => ['reputation:assertion'], 'bound_ids' => ['claim']}],
  'listing-explicit-asn' => [f.sbl('asn'), {'forms' => ['reputation:assertion'], 'bound_ids' => ['claim']}],
  'listing-asn-associated-address' => [f.sbl('network'), {'forms' => ['inet:ipv4'], 'bound_ids' => ['infrastructure']}]}
FileUtils.mkdir_p(File.join(__dir__, 'cases'))
cases.each do |name, pair|
  data, oracle = pair
  data.delete('contract')
  data['contract_path'] = 'contracts/semantics/' + data['pattern'] + '.json'
  data['expected'] = oracle.merge('execution_status' => 'complete', 'assessment_acceptance' => 'not_evaluated')
  File.write(File.join(__dir__, 'cases', name + '.json'), JSON.pretty_generate(data) + "\n")
end
