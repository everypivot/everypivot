#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative 'semantic_contract'

class SemanticContractTest < Minitest::Test
  C = EveryPivot::SemanticContract

  def example
    {
      'contract' => C::ID, 'version' => '1.0', 'pattern' => {'id' => 'TEST_BINDING', 'version' => '3.0.0'},
      'parameters' => {'seed' => {'type' => 'record_id', 'required' => true, 'description' => 'Exact starting record'}},
      'branches' => [{
        'id' => 'declared',
        'bindings' => [
          {'name' => 'seed', 'kind' => 'entity', 'types' => ['code:repo'], 'where' => {'op' => 'eq', 'left' => {'ref' => 'seed.id'}, 'right' => {'param' => 'seed'}}},
          {'name' => 'declaration', 'kind' => 'assertion', 'types' => ['declares_source_repository'], 'where' => {'op' => 'eq', 'left' => {'ref' => 'declaration.object'}, 'right' => {'ref' => 'seed.id'}}},
          {'name' => 'package', 'kind' => 'entity', 'types' => ['it:prod:softver'], 'where' => {'op' => 'eq', 'left' => {'ref' => 'package.id'}, 'right' => {'ref' => 'declaration.subject'}}}
        ],
        'where' => {'op' => 'present', 'value' => {'ref' => 'declaration.evidence'}},
        'result' => {'mode' => 'bound', 'binding' => 'package', 'form' => 'it:prod:softver', 'identity' => [{'ref' => 'package.id'}], 'fields' => {'source_declaration' => {'ref' => 'declaration.id'}}}
      }]
    }
  end

  def test_compiles_explicit_earlier_bound_projection_without_last_hop_guess
    x = example
    x['branches'][0]['result'] = {'mode' => 'bound', 'binding' => 'seed', 'form' => 'code:repo', 'identity' => [{'ref' => 'seed.id'}], 'fields' => {}}
    assert_empty C.validate(x)
    compiled = C.compile(x)
    assert_equal 'seed', compiled.dig('branches', 0, 'result', 'binding')
    compiled['pattern']['id'] = 'changed'
    assert_equal 'TEST_BINDING', x.dig('pattern', 'id')
  end

  def test_undefined_forward_variables_and_duplicate_bindings_are_rejected
    x = example
    x['branches'][0]['bindings'][0]['where']['right'] = {'ref' => 'package.id'}
    assert_match(/unbound/, C.validate(x).join)
    x = example
    x['branches'][0]['bindings'][1]['name'] = 'seed'
    assert_match(/reused/, C.validate(x).join)
  end

  def test_unknown_grammar_and_opaque_legacy_strings_never_execute
    x = example
    x['branches'][0]['where'] = {'op' => 'eval', 'code' => 'sample.observed >= string.extracted'}
    assert_raises(C::InvalidContract) { C.compile(x) }
    x['version'] = '9.0'
    assert_raises(C::UnsupportedContract) { C.compile(x) }
    x = example
    x['branches'][0]['where'] = 'sample.observed >= string.extracted'
    assert_raises(C::InvalidContract) { C.compile(x) }
  end

  def test_closed_grammar_rejects_arbitrary_semantics_and_untyped_policies
    x = example
    x['constraints'] = {'magic' => true}
    assert_match(/unknown/, C.validate(x).join)
    x = example
    x['branches'][0]['policies'] = [{'id' => 'filter', 'revision' => '1', 'scope' => 'path', 'subject' => {'ref' => 'seed.id'}, 'when' => {'op' => 'present', 'value' => {'ref' => 'seed.id'}}, 'reason' => 'Selected exclusion'}]
    assert_match(/default_enabled/, C.validate(x).join)
  end

  def test_identity_hash_is_key_order_stable_but_preserves_array_order_and_types
    assert_equal C.digest({'b' => 1, 'a' => 2}), C.digest({'a' => 2, 'b' => 1})
    refute_equal C.digest([1, 2]), C.digest([2, 1])
    refute_equal C.digest(1), C.digest('1')
  end

  def test_contract_literals_must_be_finite_acyclic_json
    [Float::INFINITY, Object.new, {1 => 'not a JSON key'}].each do |bad|
      x = example
      x['branches'][0]['result']['fields']['raw'] = {'literal' => bad}
      assert_raises(C::InvalidContract) { C.compile(x) }
    end
    cycle = []
    cycle << cycle
    x = example
    x['branches'][0]['result']['fields']['raw'] = {'literal' => cycle}
    assert_raises(C::InvalidContract) { C.compile(x) }
  end

  def test_reference_is_digest_pattern_version_and_output_bound
    Dir.mktmpdir('ep-semantic-contract-') do |root|
      FileUtils.mkdir_p(File.join(root, 'contracts/semantics'))
      rel = 'contracts/semantics/TEST_BINDING.json'
      bytes = JSON.pretty_generate(example)
      File.binwrite(File.join(root, rel), bytes)
      ref = {'contract' => C::ID, 'version' => '1.0', 'path' => rel, 'sha256' => Digest::SHA256.hexdigest(bytes)}
      pattern = {'id' => 'TEST_BINDING', 'version' => '3.0.0', 'target' => 'it:prod:softver'}
      assert_equal example, C.load_reference(ref, pattern, root: root)
      assert_raises(C::InvalidContract) { C.load_reference(ref, pattern.merge('version' => '2.0.0'), root: root) }
      assert_raises(C::InvalidContract) { C.load_reference(ref, pattern.merge('target' => 'inet:fqdn'), root: root) }
      assert_raises(C::InvalidContract) { C.load_reference(ref.merge('path' => '../outside.json'), pattern, root: root) }
      File.binwrite(File.join(root, rel), bytes + "\n")
      assert_raises(C::InvalidContract) { C.load_reference(ref, pattern, root: root) }
    end
  end

  def test_digest_pinned_contract_rejects_duplicate_members_at_every_depth
    Dir.mktmpdir('ep-semantic-duplicate-') do |root|
      FileUtils.mkdir_p(File.join(root, 'contracts/semantics'))
      rel='contracts/semantics/TEST_BINDING.json'
      pattern={'id'=>'TEST_BINDING','version'=>'3.0.0','target'=>'it:prod:softver'}
      [JSON.generate(example).sub('{','{"version":"999.0",'), JSON.generate(example).sub('"mode":"bound"','"mode":"construct","mode":"bound"')].each do |bytes|
        File.write(File.join(root,rel),bytes)
        ref={'contract'=>C::ID,'version'=>'1.0','path'=>rel,'sha256'=>Digest::SHA256.hexdigest(bytes)}
        assert_raises(C::InvalidContract){C.load_reference(ref,pattern,root:root)}
        assert_raises(C::InvalidContract){C.parse(bytes)}
      end
    end
  end
end
