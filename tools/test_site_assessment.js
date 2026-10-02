// Run with Node.js from a checkout or stable pack containing site/index.html.
// Execute the shipped standalone application, not a second boundary implementation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const siteRoot = path.join(__dirname, '../site');
const html = fs.readFileSync(path.join(siteRoot, 'index.html'), 'utf8');
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
  .filter((match) => !/\bsrc\s*=/i.test(match[1])).map((match) => match[2]);
assert.equal(scripts.length, 1, 'The compact browser has one standalone application.');

function renderRegistry(patterns, overrides = {}) {
  const registry = {
    release: 'v0.5.0', published_at: '2026-09-10',
    schema_versions: {pivot_pattern: '1.5'},
    counts: {validated: patterns.filter((p) => p.lane === 'validated').length,
      working_set: patterns.filter((p) => p.lane === 'working_set').length,
      deferred: patterns.filter((p) => p.lane === 'deferred').length},
    patterns, ...overrides
  };
  const before = JSON.stringify(registry);
  const nodes = new Map();
  const makeNode = () => ({
    innerHTML: '', textContent: '', children: [], handlers: {},
    appendChild(child) { this.children.push(child); },
    addEventListener(name, handler) { this.handlers[name] = handler; }
  });
  const getNode = (id) => {
    if (!nodes.has(id)) nodes.set(id, makeNode());
    return nodes.get(id);
  };
  const lanes = ['validated', 'working_set', 'deferred'].map((lane) => ({
    ...makeNode(), checked: lane !== 'deferred', getAttribute: () => lane
  }));
  const context = {
    console, window: {__EVERYPIVOT_REGISTRY__: registry},
    document: {getElementById: getNode, createElement: makeNode,
      querySelectorAll: () => lanes}
  };
  vm.createContext(context);
  vm.runInContext(scripts[0], context, {filename: 'site/index.html', timeout: 1000});
  assert.equal(JSON.stringify(registry), before, 'Rendering must not change evidence or assessment records.');
  return {body: () => getNode('list-host').innerHTML, getNode, lanes};
}

const compatibility = {contract_version: '0.4-draft', coverage: {complete: true, assessment_acceptance_evaluated: false}};
const evidence = {
  id: 'CTI_FEATURE_MATCH', name: 'Feature lookup', lane: 'validated', category: 'CTI',
  path: 'graph-pivots/validated/CTI_FEATURE_MATCH.yaml', pattern_schema_version: 1.5,
  assessment_mode: 'evidence_only',
  assessment_compatibility: {...compatibility, status: 'evidence_only'},
  hazards: ['Benign software and shared builders can explain this feature.']
};
const candidate = {
  ...evidence, id: 'ADTECH_CANDIDATE', lane: 'working_set',
  assessment_mode: 'candidate_assessment',
  assessment_compatibility: {...compatibility, status: 'candidate_compatible'},
  assessment: {claim: 'indicates', basis: 'assessed', scope: 'incident_level', subject_role: 'observation', object_role: 'incident'},
  assessment_requirements: [
    'Independently support the incident association.',
    'Corroborate the chain and address alternative explanations.',
    'Preserve <img src=x onerror="alert(1)"> & \'quoted\' evidence as text.',
    'Apply case review before any conclusion is accepted.'
  ]
};
function bindCheck(record) {
  record.assessment_compatibility.manifest_sha256 = '5416bf429a34afccb4e6657807c26b83491a39bdcbd6c9a313530cadbf032881';
  record.assessment_compatibility.checked_input = JSON.parse(JSON.stringify(Object.fromEntries(
    ['pattern_schema_version', 'assessment_mode', 'assessment', 'assessment_requirements']
      .filter((key) => Object.hasOwn(record, key)).map((key) => [key, record[key]]))));
}
bindCheck(evidence);
bindCheck(candidate);
const evidenceBody = renderRegistry([evidence]).body();
assert.match(evidenceBody, /Evidence only\. No default assessment\./);
assert.doesNotMatch(evidenceBody, /candidate claim|Qualifying evidence for the candidate/);
assert.match(evidenceBody, /Benign software and shared builders/);

const candidateBody = renderRegistry([candidate]).body();
assert.match(candidateBody, /Conditional candidate only\. A match is not an accepted conclusion\./);
assert.match(candidateBody, /candidate claim<\/div><div class="v">indicates/);
assert.match(candidateBody, /incident_level/);
const requirements = candidateBody.match(/<h4>Qualifying evidence for the candidate<\/h4><ul>(.*?)<\/ul>/s);
assert.ok(requirements, 'Every conditional hint must display its qualifying evidence.');
assert.equal((requirements[1].match(/<li>/g) || []).length, candidate.assessment_requirements.length);
assert.ok(requirements[1].includes('<li>Independently support the incident association.</li>'));
assert.ok(requirements[1].includes('<li>Corroborate the chain and address alternative explanations.</li>'));
assert.ok(requirements[1].includes('<li>Apply case review before any conclusion is accepted.</li>'));
assert.ok(requirements[1].includes('&lt;img src=x onerror=&quot;alert(1)&quot;&gt; &amp; &#39;quoted&#39;'));
assert.doesNotMatch(candidateBody, /<img\b|>Accepted assessment</);
assert.match(candidateBody, /Benign software and shared builders/);
assert.match(candidateBody, /github\.com\/everypivot\/everypivot\/blob\/v0\.5\.0\//);
const reorderedHint = Object.fromEntries(Object.entries(candidate.assessment).reverse());
assert.match(renderRegistry([{...candidate, assessment: reorderedHint}]).body(), /Conditional candidate only/);

const unsafe = [
  {...evidence, assessment_mode: undefined, assessment_compatibility: undefined, assessment: candidate.assessment},
  {...candidate, assessment_mode: 'unknown'},
  {...candidate, assessment_requirements: []},
  {...candidate, assessment_requirements: undefined},
  {...candidate, assessment_compatibility: {status: 'incompatible'}},
  {...candidate, assessment_compatibility: {status: 'incomplete'}},
  {...evidence, assessment: candidate.assessment},
  {...evidence, assessment: null},
  {...evidence, assessment_requirements: []},
  {...candidate, pattern_schema_version: 1.4},
  {...candidate, pattern_schema_version: 'unknown'},
  {...candidate, assessment_requirements: ['  ']},
  {...candidate, assessment_requirements: [true]},
  {...candidate, assessment: {claim: 'indicates'}},
  {...candidate, assessment: []},
  {...candidate, assessment_compatibility: {...candidate.assessment_compatibility, contract_version: 'unknown'}},
  {...candidate, assessment_compatibility: {...candidate.assessment_compatibility, coverage: {complete: false, assessment_acceptance_evaluated: false}}},
  {...candidate, assessment_compatibility: {...candidate.assessment_compatibility, coverage: {complete: true, assessment_acceptance_evaluated: true}}},
  ...[
    {scope: 'entity_level'}, {claim: 'targets'}, {subject_role: 'tool'},
    {object_role: 'tool'}, {object_kind: 'invented_kind'}, {basis: 'demonstrated'},
    {unexpected: 'field'}
  ].map((change) => ({...candidate, assessment: {...candidate.assessment, ...change}})),
  {...candidate, assessment_requirements: ['A traversal match is sufficient.']},
  {...candidate, assessment_requirements: [...candidate.assessment_requirements].reverse()},
  {...candidate, assessment_compatibility: {...candidate.assessment_compatibility, checked_input: undefined}},
  {...candidate, assessment_compatibility: {...candidate.assessment_compatibility, manifest_sha256: 'corrupt'}}
];
for (const record of unsafe) {
  const body = renderRegistry([record]).body();
  assert.match(body, /Assessment mapping unavailable or unchecked\./);
  assert.doesNotMatch(body, /candidate claim|Qualifying evidence for the candidate|Conditional candidate only/);
  assert.match(body, /Benign software and shared builders/);
}

// Construct independently bound legacy records: refusal must come from the
// current-consumer contract even when the legacy diagnostic itself is complete.
const boundaryCases = [];
function boundaryCase(label, original, change, rebind = false) {
  const record = JSON.parse(JSON.stringify(original));
  change(record);
  if (rebind) bindCheck(record);
  boundaryCases.push({label, record});
}
for (const version of [1.1, 1.2, 1.3, 1.4, '1.4']) {
  boundaryCase(`complete legacy ${version} diagnostic`, candidate, (record) => {
    record.pattern_schema_version = version;
    delete record.assessment_mode;
    delete record.assessment_requirements;
  }, true);
}
for (const version of [undefined, null, 'unknown', 1.7, [1.5], {version: 1.5}]) {
  boundaryCase(`unsupported schema ${String(version)}`, candidate, (record) => {
    if (version === undefined) delete record.pattern_schema_version;
    else record.pattern_schema_version = version;
  }, true);
}
for (const mode of [undefined, null, 'unknown', 'evidence_only']) {
  boundaryCase(`candidate with mode ${String(mode)}`, candidate, (record) => {
    if (mode === undefined) delete record.assessment_mode;
    else record.assessment_mode = mode;
  }, true);
}
for (const requirements of [undefined, null, [], [''], [null]]) {
  boundaryCase(`candidate requirements ${JSON.stringify(requirements)}`, candidate, (record) => {
    if (requirements === undefined) delete record.assessment_requirements;
    else record.assessment_requirements = requirements;
  }, true);
}
for (const key of ['assessment', 'assessment_requirements']) {
  boundaryCase(`evidence-only forbids present null ${key}`, evidence, (record) => {
    record[key] = null;
  }, true);
  boundaryCase(`checked_input distinguishes absent ${key} from null`, evidence, (record) => {
    record.assessment_compatibility.checked_input[key] = null;
  });
}
for (const [key, value] of [['scope', 'entity_level'], ['subject_role', 'tool'],
  ['object_role', 'tool'], ['basis', 'demonstrated']]) {
  boundaryCase(`altered checked hint ${key}`, candidate, (record) => {
    record.assessment_compatibility.checked_input.assessment[key] = value;
  });
}
boundaryCase('altered checked requirements', candidate, (record) => {
  record.assessment_compatibility.checked_input.assessment_requirements = ['A match is sufficient.'];
});
for (const original of [candidate, evidence]) {
  for (const version of [undefined, null, 'unknown']) {
    boundaryCase(`${original.assessment_mode} contract version ${String(version)}`, original, (record) => {
      if (version === undefined) delete record.assessment_compatibility.contract_version;
      else record.assessment_compatibility.contract_version = version;
    });
  }
  for (const status of [undefined, null, 'unknown', 'incomplete', 'incompatible',
    original === candidate ? 'evidence_only' : 'candidate_compatible']) {
    boundaryCase(`${original.assessment_mode} compatibility status ${String(status)}`, original, (record) => {
      if (status === undefined) delete record.assessment_compatibility.status;
      else record.assessment_compatibility.status = status;
    });
  }
  for (const digest of [undefined, null, '', '0'.repeat(64)]) {
    boundaryCase(`${original.assessment_mode} manifest digest ${String(digest)}`, original, (record) => {
      if (digest === undefined) delete record.assessment_compatibility.manifest_sha256;
      else record.assessment_compatibility.manifest_sha256 = digest;
    });
  }
  for (const input of [undefined, null, {}, {pattern_schema_version: 1.4}]) {
    boundaryCase(`${original.assessment_mode} stale checked_input ${JSON.stringify(input)}`, original, (record) => {
      if (input === undefined) delete record.assessment_compatibility.checked_input;
      else record.assessment_compatibility.checked_input = input;
    });
  }
  for (const coverage of [undefined, null, {}, {complete: 'true', assessment_acceptance_evaluated: false},
    {complete: true}, {complete: true, assessment_acceptance_evaluated: null}]) {
    boundaryCase(`${original.assessment_mode} incomplete coverage ${JSON.stringify(coverage)}`, original, (record) => {
      if (coverage === undefined) delete record.assessment_compatibility.coverage;
      else record.assessment_compatibility.coverage = coverage;
    });
  }
}
for (const {label, record} of boundaryCases) {
  const body = renderRegistry([record]).body();
  assert.match(body, /Assessment mapping unavailable or unchecked\./, label);
  assert.doesNotMatch(body, /candidate claim|Qualifying evidence for the candidate|Conditional candidate only|Evidence only\. No default assessment\./, label);
  assert.match(body, /Benign software and shared builders/, label);
}

function semanticRecord(original = evidence) {
  const record = JSON.parse(JSON.stringify(original));
  record.pattern_schema_version = '1.6';
  record.version = '3.0.0';
  record.target = 'file:bytes';
  record.execution = {contract: 'everypivot.semantic_pattern', version: '1.0',
    path: `contracts/semantics/${record.id}.json`, sha256: 'a'.repeat(64)};
  bindCheck(record);
  record.semantic_execution = {
    status: 'contract_valid', contract_id: record.execution.contract, contract_version: record.execution.version,
    reference_sha256: record.execution.sha256, runtime_acceptance: 'not_evaluated',
    checked_input: JSON.parse(JSON.stringify(Object.fromEntries(
      ['id', 'version', 'pattern_schema_version', 'target', 'execution'].map((key) => [key, record[key]])))),
    coverage: {reference_digest_verified: true, pattern_identity_verified: true,
      contract_shape_and_bindings_validated: true, runtime_executed: false,
      evidence_acceptance_evaluated: false, assessment_acceptance_evaluated: false},
    summary: {parameters: {}, branches: [{id: 'bound_file',
      bindings: [{name: 'file', kind: 'entity', types: ['file:bytes']}],
      result: {mode: 'bound', binding: 'file', form: 'file:bytes'},
      time_bindings: [{value: {ref: 'file.times.available'}, object: {ref: 'file.id'}, occurrence: {ref: 'file.id'}}],
      knowledge: [{ref: 'file.times.available'}]}]}
  };
  return record;
}
for (const original of [evidence, candidate]) {
  for (const schemaVersion of ['1.6', 1.6]) {
    const record = semanticRecord(original);
    record.pattern_schema_version = schemaVersion;
    bindCheck(record);
    record.semantic_execution.checked_input.pattern_schema_version = schemaVersion;
    const body = renderRegistry([record]).body();
    assert.match(body, /Declared contract checked\. Runtime acceptance not evaluated\./);
    assert.match(body, /bound_file: bound file:bytes/);
    assert.match(body, /1 record bindings; 1 time bindings/);
    assert.match(body, /explicit as-known cutoff operands/);
    assert.match(body, original === candidate ? /Conditional candidate only/ : /Evidence only\. No default assessment\./);
    assert.doesNotMatch(body, /Runtime accepted|Accepted assessment/);
  }
}
const semanticUnsafe = [];
function semanticUnsafeCase(label, change) {
  const record = semanticRecord();
  change(record);
  semanticUnsafe.push({label, record});
}
for (const key of ['id', 'version', 'target', 'pattern_schema_version']) {
  semanticUnsafeCase(`stale semantic checked ${key}`, (record) => { record[key] = 'changed'; });
  semanticUnsafeCase(`missing semantic checked ${key}`, (record) => { delete record[key]; });
}
for (const value of [undefined, null, {}, [], 'contract']) {
  semanticUnsafeCase(`missing/malformed execution ${JSON.stringify(value)}`, (record) => { record.execution = value; });
}
for (const [key, value] of [['contract', 'other'], ['version', '9.0'], ['sha256', 'b'.repeat(64)],
  ['sha256', 'A'.repeat(64)], ['sha256', 'a'.repeat(64) + '\n'], ['path', 'contracts/semantics/OTHER.json'],
  ['path', '../outside.json'], ['extra', 'not part of the reference']]) {
  semanticUnsafeCase(`stale/invalid execution ${key} ${value}`, (record) => { record.execution[key] = value; });
}
for (const value of [undefined, null, {}, [], 'contract']) {
  semanticUnsafeCase(`missing/malformed semantic check ${JSON.stringify(value)}`, (record) => { record.semantic_execution = value; });
}
for (const [key, value] of [['status', 'accepted'], ['status', 'not_declared'], ['contract_id', 'other'],
  ['contract_version', '9.0'], ['reference_sha256', 'b'.repeat(64)], ['runtime_acceptance', 'accepted'],
  ['checked_input', {}], ['summary', {}]]) {
  semanticUnsafeCase(`invalid semantic diagnostic ${key}`, (record) => { record.semantic_execution[key] = value; });
}
for (const key of ['reference_digest_verified', 'pattern_identity_verified', 'contract_shape_and_bindings_validated']) {
  semanticUnsafeCase(`incomplete semantic coverage ${key}`, (record) => { record.semantic_execution.coverage[key] = false; });
}
for (const key of ['runtime_executed', 'evidence_acceptance_evaluated', 'assessment_acceptance_evaluated']) {
  semanticUnsafeCase(`manufactured acceptance ${key}`, (record) => { record.semantic_execution.coverage[key] = true; });
}
semanticUnsafeCase('summary result outside declared target', (record) => { record.semantic_execution.summary.branches[0].result.form = 'risk:assessment'; });
for (const {label, record} of semanticUnsafe) {
  const body = renderRegistry([record]).body();
  assert.match(body, /Execution contract unavailable or unchecked\./, label);
  assert.doesNotMatch(body, /Declared contract checked|declared results|declared bindings|explicit as-known cutoff operands/, label);
  assert.match(body, /Benign software and shared builders/, label);
}
const noExecution = JSON.parse(JSON.stringify(evidence));
noExecution.version = '2.0.0';
noExecution.target = 'file:bytes';
noExecution.semantic_execution = {status: 'not_declared', runtime_acceptance: 'not_evaluated',
  checked_input: Object.fromEntries(['id', 'version', 'pattern_schema_version', 'target'].map((key) => [key, noExecution[key]])),
  coverage: {reference_digest_verified: false, pattern_identity_verified: false, contract_shape_and_bindings_validated: false,
    runtime_executed: false, evidence_acceptance_evaluated: false, assessment_acceptance_evaluated: false}};
assert.match(renderRegistry([noExecution]).body(), /No executable contract declared\./);
assert.doesNotMatch(renderRegistry([noExecution]).body(), /Declared contract checked/);
const independentlyUnchecked = semanticRecord(candidate);
delete independentlyUnchecked.semantic_execution;
assert.match(renderRegistry([independentlyUnchecked]).body(), /Conditional candidate only/);
assert.match(renderRegistry([independentlyUnchecked]).body(), /Execution contract unavailable or unchecked\./);

// Exercise the actual wired filter callbacks and preserve requirements after rerender.
const browser = renderRegistry([evidence, candidate, {...evidence, id: 'DEFERRED_ONLY', lane: 'deferred'}]);
assert.equal(browser.getNode('c-total').textContent, 3);
assert.equal(browser.getNode('result-count').textContent, '2 patterns');
browser.getNode('q').handlers.input({target: {value: 'ADTECH_CANDIDATE'}});
assert.equal(browser.getNode('result-count').textContent, '1 pattern');
assert.match(browser.body(), /Qualifying evidence for the candidate/);
browser.getNode('q').handlers.input({target: {value: ''}});
browser.lanes[2].checked = true;
browser.lanes[2].handlers.change();
assert.equal(browser.getNode('result-count').textContent, '3 patterns');
assert.match(browser.body(), /DEFERRED_ONLY/);

const absent = renderRegistry([], {patterns: null});
assert.match(absent.body(), /Could not load registry index/);
for (const retired of ['assets/app.js', 'assets/styles.css', 'pattern.html', 'patterns.html', 'schema.html', 'pattern-library.html']) {
  assert.equal(fs.existsSync(path.join(siteRoot, retired)), false, `Retired UI must remain removed: ${retired}`);
  assert.equal(html.includes(`./${retired}`), false);
}
const generated = JSON.parse(fs.readFileSync(path.join(siteRoot, 'data/registry-index.json'), 'utf8'));
const generatedBody = renderRegistry(generated.patterns, generated).body();
assert.match(generatedBody, /Conditional candidate only/);
assert.doesNotMatch(generatedBody, /Assessment mapping unavailable or unchecked/);
console.log(`Compact site boundary: evidence-only, conditional candidate, ${unsafe.length + boundaryCases.length} unsafe assessment states, ${semanticUnsafe.length} unsafe execution states, v1.5/v1.6 compatibility, escaped complete requirements, read-only rendering, filters, and retired routes pass.`);
