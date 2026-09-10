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
  {...candidate, assessment_compatibility: {...candidate.assessment_compatibility, coverage: {complete: true, assessment_acceptance_evaluated: true}}}
];
for (const record of unsafe) {
  const body = renderRegistry([record]).body();
  assert.match(body, /Assessment mapping unavailable or unchecked\./);
  assert.doesNotMatch(body, /candidate claim|Qualifying evidence for the candidate|Conditional candidate only/);
  assert.match(body, /Benign software and shared builders/);
}

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
console.log(`Compact site boundary: evidence-only, conditional candidate, ${unsafe.length} unsafe states, escaped complete requirements, read-only rendering, filters, and retired routes pass.`);
