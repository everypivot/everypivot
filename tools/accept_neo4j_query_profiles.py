#!/usr/bin/env python3
"""Bounded synthetic native acceptance; Python standard library, Neo4j 5.x HTTP API.
Never use against a user database. Requires a separately provisioned ownership marker.
"""
import argparse
import collections
import copy
import datetime as dt
import gzip
import hashlib
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

class AcceptanceError(Exception):
    pass

class DatabaseError(AcceptanceError):
    pass

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)

def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()

def multiset(values):
    return collections.Counter(canonical(v) for v in values)

def compare(actual, expected, label='records'):
    if not isinstance(actual, list) or multiset(actual) != multiset(expected):
        raise AcceptanceError(f'{label}: complete record/multiplicity mismatch')

def traversals(rows):
    if any(not isinstance(r,dict) or set(r)!={'everypivot_traversal'} for r in rows):
        raise AcceptanceError('wrong result columns')
    return [r['everypivot_traversal'] for r in rows]

def date_input(value):
    if not isinstance(value, str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', value):
        raise AcceptanceError('expected YYYY-MM-DD calendar date; timestamps/timezones unsupported')
    try:
        return dt.date.fromisoformat(value)
    except ValueError as e:
        raise AcceptanceError(str(e)) from e

def preflight(parameters, graph):
    date_input(parameters.get('as_of'))
    if not isinstance(parameters.get('source_id'), str) or not parameters['source_id']:
        raise AcceptanceError('source_id must be a nonempty string')
    for edge in graph['relationships']:
        date_input(edge.get('properties', {}).get('seen'))
    for node in graph['nodes']:
        if node.get('negative_node_list') is not None and not isinstance(node['negative_node_list'], str):
            raise AcceptanceError('negative_node_list must be scalar text')

def decode_string(raw):
    out=[]; i=0; escapes={'n':'\n','r':'\r','t':'\t','b':'\b','f':'\f',"'":"'",'"':'"','\\':'\\'}
    while i<len(raw):
        c=raw[i];i+=1
        if c=='\\':
            c=raw[i];i+=1
            if c=='u': c=chr(int(raw[i:i+4],16));i+=4
            elif c in escapes:c=escapes[c]
            else:raise AcceptanceError('unsupported Cypher string escape')
        out.append(c)
    return ''.join(out)

def executable(text):
    """Remove only complete shell parameter lines; preserve all other bytes."""
    params={}; body=[]
    for line in text.splitlines(keepends=True):
        if line.startswith(':param '):
            m=re.fullmatch(r":param ([a-z_]+) => '((?:\\.|[^'])*)';\s*",line)
            if not m or m[1] in params:raise AcceptanceError('unsupported or duplicate shell parameter directive')
            params[m[1]]=decode_string(m[2])
        elif line.lstrip().startswith(':'):
            raise AcceptanceError('unsupported shell directive')
        else:body.append(line)
    return ''.join(body),params

def statements(body):
    # Loader-only splitter, respecting quoted strings and line comments.
    parts=[];start=0;quote=None;escape=False;comment=False;i=0
    while i<len(body):
        c=body[i]
        if comment:
            if c=='\n':comment=False
        elif quote:
            if escape:escape=False
            elif c=='\\':escape=True
            elif c==quote:quote=None
        elif c in "'\"`":quote=c
        elif body[i:i+2]=='//':comment=True
        elif c==';':
            parts.append(body[start:i]);start=i+1
        i+=1
    if body[start:].strip():parts.append(body[start:])
    return [p for p in parts if p.strip()]

class Native:
    def __init__(self,url,journal,timeout=30):
        parsed=urllib.parse.urlparse(url)
        if parsed.scheme!='http' or parsed.hostname!='127.0.0.1' or parsed.username or parsed.path!='/db/neo4j/tx/commit':
            raise AcceptanceError('only explicit loopback task database endpoint is supported')
        self.url=url;self.journal=journal;self.timeout=timeout
        self.opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    def run(self,query,params=None,columns=None):
        start=time.monotonic();payload={'statements':[{'statement':query,'parameters':params or {},'resultDataContents':['row']}]}
        entry={'query':query,'parameters':params or {}}
        try:
            req=urllib.request.Request(self.url,canonical(payload).encode(),{'Content-Type':'application/json'})
            with self.opener.open(req,timeout=self.timeout) as r:
                result=json.load(r);entry['http_status']=r.status;entry['response']=result
            if result.get('errors'):raise DatabaseError('database error: '+canonical(result['errors']))
            if len(result.get('results',[]))!=1:raise AcceptanceError('missing structured result')
            row=result['results'][0]
            if columns is not None and row['columns']!=columns:raise AcceptanceError('wrong result columns')
            return [dict(zip(row['columns'],x['row'],strict=True)) for x in row['data']]
        except Exception as e:
            entry['failure']=str(e);raise
        finally:
            entry['seconds']=time.monotonic()-start
            self.journal.write(canonical(entry)+'\n');self.journal.flush()
    def snapshot(self):
        nodes=self.run('MATCH (n:EveryPivotNode) RETURN properties(n) AS node')
        edges=self.run('MATCH (a:EveryPivotNode)-[r]->(b:EveryPivotNode) RETURN a.id AS from, b.id AS to, type(r) AS type, properties(r) AS properties')
        return {'nodes':[r['node'] for r in nodes],'relationships':edges}
    def state(self):
        return {
            'nodes': self.run('MATCH (n) RETURN elementId(n) AS identity, labels(n) AS labels, properties(n) AS properties'),
            'relationships': self.run('MATCH (a)-[r]->(b) RETURN elementId(r) AS identity, elementId(a) AS start, elementId(b) AS end, type(r) AS type, properties(r) AS properties')}
    def reset(self):
        self.run('MATCH (n:EveryPivotNode) DETACH DELETE n')
    def load(self,graph):
        self.reset()
        nodes=[{k:v for k,v in n.items() if v is not None} for n in graph['nodes']]
        for offset in range(0,len(nodes),1000):
            self.run('UNWIND $nodes AS props CREATE (n:EveryPivotNode) SET n = props',{'nodes':nodes[offset:offset+1000]})
        groups=collections.defaultdict(list)
        for e in graph['relationships']:
            if not re.fullmatch('[A-Z_]+',e['type']):raise AcceptanceError('unsupported fixture relation')
            groups[e['type']].append(e)
        for typ,edges in groups.items():
            for offset in range(0,len(edges),1000):
                self.run(f'UNWIND $edges AS e MATCH (a:EveryPivotNode {{id:e.from}}), (b:EveryPivotNode {{id:e.to}}) CREATE (a)-[r:{typ}]->(b) SET r=e.properties',{'edges':edges[offset:offset+1000]})

def expected_graph(graph):
    g=copy.deepcopy(graph)
    for n in g['nodes']:
        for k in list(n):
            if n[k] is None:del n[k]
    for r in g['relationships']:
        r['properties']={k:v for k,v in r['properties'].items() if v is not None}
    return g

def check_graph(actual,expected):
    for key in ['nodes','relationships']:compare(actual[key],expected[key],key)

def records(contract,source,targets):
    c=contract;rel=c['relation'].upper()
    return [{'pattern_id':c['pattern_id'],'query_profile_id':'neo4j_cypher_v0','source':source,'target':t,'relation':c['relation'],
             'evidence_paths':[[t,rel,source] if c['direction']=='in' else [source,rel,t]],
             'features':{'path_length':1,'temporal_window_days':c['window_days'],'negative_node_lists_applied':c['negative_lists']},
             'caveats':c['caveats'],'blocked_assertions':c['blocked_assertions']} for t in targets]

def scenario_graph(c,count=1):
    source={'id':'acceptance:source','form':c['source_form'],'label':'synthetic source'}
    nodes=[source];edges=[];targets=[]
    for i in range(count):
        tid=f'acceptance:target:{i:05d}';targets.append(tid)
        nodes.append({'id':tid,'form':c['target_form'],'label':'synthetic target'})
        a,b=(tid,source['id']) if c['direction']=='in' else (source['id'],tid)
        edges.append({'from':a,'to':b,'type':c['relation'].upper(),'properties':{'seen':'2024-02-29','source':'synthetic acceptance'}})
    return {'nodes':nodes,'relationships':edges},targets

def scenarios(c,high):
    g,targets=scenario_graph(c);p={'source_id':'acceptance:source','as_of':'2024-03-01'}
    def item(name,graph=None,params=None,expect=None,kind='acceptance'):
        return {'name':name,'graph':graph if graph is not None else copy.deepcopy(g),'parameters':params if params is not None else dict(p),'targets':targets if expect is None else expect,'kind':kind}
    yield item('positive-leap-day')
    if c['pattern_id']=='OSINT_SSH_HOSTKEY_CLUSTER':
        for label in c['negative_lists']:
            x=copy.deepcopy(g);x['nodes'][1]['form']='inet:fqdn';x['nodes'][1]['negative_node_list']=label
            yield item('fqdn-ipv4-only-exclusion-'+label,x)
    for name,offset,ok in [('lower-boundary',-c['window_days'],True),('upper-boundary',0,True),('one-day-before',-c['window_days']-1,False),('one-day-after-future',1,False)]:
        x=copy.deepcopy(g);x['relationships'][0]['properties']['seen']=(dt.date(2024,3,1)+dt.timedelta(days=offset)).isoformat()
        yield item(name,x,expect=targets if ok else [])
    yield item('as-of-leap-day',params=dict(p,as_of='2024-02-29'))
    x=copy.deepcopy(g);x['relationships'][0]['from'],x['relationships'][0]['to']=x['relationships'][0]['to'],x['relationships'][0]['from']
    yield item('wrong-direction',x,expect=[])
    x=copy.deepcopy(g);x['relationships'][0]['type']='UNRELATED'
    yield item('wrong-relation',x,expect=[])
    for index,name in [(0,'wrong-source-form'),(1,'wrong-target-form')]:
        x=copy.deepcopy(g);x['nodes'][index]['form']='unrelated:form';yield item(name,x,expect=[])
    yield item('unrelated-source',params=dict(p,source_id='acceptance:absent'),expect=[])
    side=0 if c['suppression_side']=='source' else 1
    for label in c['negative_lists']:
        x=copy.deepcopy(g);x['nodes'][side]['negative_node_list']=label;yield item('suppression-'+label,x,expect=[])
    x=copy.deepcopy(g);x['nodes'][side]['negative_node_list']='unmatched';yield item('unmatched-suppression-label',x)
    x=copy.deepcopy(g);x['nodes'][1-side]['negative_node_list']=c['negative_lists'][0];yield item('suppression-other-endpoint-not-applicable',x)
    x=copy.deepcopy(g);x['relationships']*=2;yield item('duplicate-relationships',x,expect=targets*2,kind='cardinality-observation')
    for field in ['as_of','seen']:
        for name,val in [('null',None),('malformed','not-a-date'),('invalid-leap-day','2023-02-29'),('timestamp','2024-02-29T00:00:00Z'),('compact-date','20240229'),('integer',20240229)]:
            x=copy.deepcopy(g);q=dict(p)
            if field=='as_of':q[field]=val
            else:x['relationships'][0]['properties'][field]=val
            yield item(field+'-'+name,x,q,expect=[],kind='invalid-input-probe')
    x=copy.deepcopy(g);x['nodes'][side]['negative_node_list']=[c['negative_lists'][0]]
    yield item('list-valued-suppression-unsupported',x,expect=[],kind='invalid-input-probe')
    q=dict(p);del q['as_of']
    yield item('as_of-omitted',params=q,expect=[],kind='invalid-input-probe')
    x=copy.deepcopy(g);del x['relationships'][0]['properties']['seen']
    yield item('seen-omitted',x,expect=[],kind='invalid-input-probe')
    if high:
        x,ts=scenario_graph(c,c['high_cardinality']);yield item('above-declared-degree-cap',x,expect=ts,kind='cardinality-observation')

def run_case(db,body,c,case,out):
    start=time.monotonic();entry={'pattern_id':c['pattern_id'],**case};path=out/(c['pattern_id']+'--'+case['name']+'.json.gz')
    try:
        invalid=case['kind']=='invalid-input-probe'
        try:
            preflight(case['parameters'],case['graph']);entry['preflight']='accepted'
        except AcceptanceError as e:
            entry['preflight']={'rejected':str(e)}
            if not invalid:raise
        if invalid and entry['preflight']=='accepted':raise AcceptanceError('invalid input accepted by preflight')
        db.load(case['graph']);before=db.snapshot();check_graph(before,expected_graph(case['graph']))
        entry['persisted_before']=before
        full_before=db.state();entry['full_state_before']=full_before
        expected=records(c,case['parameters']['source_id'],case['targets']);entry['expected_records']=None if invalid else expected
        if invalid:entry['expectation']='preflight rejection; raw native behavior observed; exact evidence-only record shape still required'
        actual_runs=[];entry['actual_runs']=actual_runs
        for _ in range(2):
            try:
                raw=db.run(body,case['parameters'],columns=['everypivot_traversal'])
                actual=traversals(raw);actual_runs.append({'records':actual,'cardinality':len(actual)})
                if not invalid:compare(actual,expected)
                else:validate_observed_records(actual,c,case)
            except DatabaseError as e:
                if not invalid:raise
                actual_runs.append({'database_error':str(e)})
        entry['actual_runs']=actual_runs
        after=db.snapshot();check_graph(after,before);check_graph(db.state(),full_before);entry['persisted_after_sha256']=digest(after)
        # Ordering is not part of this comparison; both snapshots are also in the request journal.
        entry['read_only_verified']=True;entry['status']='observed-out-of-contract' if invalid else 'pass'
    except Exception as e:
        entry['status']='fail';entry['failure']=str(e)
    finally:
        entry['seconds']=time.monotonic()-start
        with gzip.open(path,'wt',encoding='utf-8') as f:json.dump(entry,f,ensure_ascii=False)
    return {k:entry[k] for k in ['pattern_id','name','kind','status','seconds'] } | ({'failure':entry['failure']} if 'failure' in entry else {})

def validate_observed_records(actual,c,case):
    targets={n['id'] for n in case['graph']['nodes'] if n['form']==c['target_form']}
    for row in actual:
        if not isinstance(row,dict) or row.get('target') not in targets:
            raise AcceptanceError('malformed/unexpected observed target')
        compare([row],records(c,case['parameters']['source_id'],[row['target']]))

def authored_case(root,db,body,c,out):
    proof={'pattern_id':c['pattern_id'],'name':'authored-repeat-load','kind':'acceptance','runs':[]}
    start=time.monotonic()
    try:
        fixture=json.loads((root/c['fixture_path']).read_text());loader_path=root/c['fixture_path'].replace('.graph.json','.load.cypher')
        loader,params=executable(loader_path.read_text());db.reset()
        graph={'nodes':[dict(n,fixture_id=fixture['fixture_id']) for n in fixture['nodes']],'relationships':fixture['relationships']}
        proof.update({'fixture':fixture,'loader_body':loader,'loader_parameters':params})
        for _ in range(2):
            run={};proof['runs'].append(run)
            for stmt in statements(loader):db.run(stmt,params)
            before=db.snapshot();run['persisted_graph']=before;check_graph(before,graph);full_before=db.state();run['full_state_before']=full_before
            raw=db.run(body,fixture['parameters'],columns=['everypivot_traversal']);run['raw_results']=raw
            actual=traversals(raw)
            expected=records(c,fixture['parameters']['source_id'],fixture['expected_result_targets'])
            run.update({'actual_records':actual,'expected_records':expected,'cardinality':len(actual)})
            compare(actual,expected)
            check_graph(db.snapshot(),before);check_graph(db.state(),full_before);run['read_only_verified']=True
        proof['status']='pass'
    except Exception as e:
        proof['status']='fail';proof['failure']=str(e)
    finally:
        proof['seconds']=time.monotonic()-start
        with gzip.open(out/(c['pattern_id']+'--authored-repeat-load.json.gz'),'wt') as f:json.dump(proof,f)
    return {k:proof[k] for k in ['pattern_id','name','kind','status','seconds']} | ({'failure':proof['failure']} if 'failure' in proof else {})

def fault_cases(db):
    proof=[]
    for name,query in [('query-error','RETURN nonexistent_variable'),
                       ('failed-fixture-load',"CREATE (n:EveryPivotNode {id:'failed-load'}) SET n.seen=date('not-a-date') RETURN n")]:
        before=db.state()
        try:
            db.run(query)
        except AcceptanceError as e:
            if 'database error:' not in str(e):raise
            check_graph(db.state(),before);proof.append({'name':name,'expected':'database error and unchanged graph','actual':str(e),'status':'pass'})
        else:raise AcceptanceError(name+' unexpectedly succeeded')
    # Use the required server-configured 10 s timeout; Community lacks the
    # Enterprise dbms.setConfigValue procedure. Finite streaming computation.
    before=db.state()
    try:
        db.run('UNWIND range(1,1000000000) AS x RETURN sum(sqrt(x)) AS value')
    except DatabaseError as e:
        if 'TransactionTimedOut' not in str(e):raise
        check_graph(db.state(),before);proof.append({'name':'server-timeout','expected':'TransactionTimedOut and unchanged graph','actual':str(e),'status':'pass'})
    else:raise AcceptanceError('bounded timeout probe unexpectedly completed; configure db.transaction.timeout=10s')
    return proof

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo-root',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parent.parent)
    parser.add_argument('--ownership-file',required=True,type=pathlib.Path)
    parser.add_argument('--output',required=True,type=pathlib.Path)
    parser.add_argument('--pattern-id',action='append')
    parser.add_argument('--high-cardinality',action='store_true')
    args=parser.parse_args();root=args.repo_root.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    input_paths=[p for folder in ['adapters','fixtures/query-profiles','tools','graph-pivots'] for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in str(p)]
    summary={'input_sha256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in input_paths},'runtime':sys.version,'argv':sys.argv,'results':[],'skips':[]};exitcode=1
    try:
        paths=sorted((root/'fixtures/query-profiles/neo4j/acceptance').glob('*.json'))
        contracts=[json.loads(p.read_text()) for p in paths]
        if args.pattern_id:
            unknown=set(args.pattern_id)-{c['pattern_id'] for c in contracts}
            if unknown:raise AcceptanceError('no matched targets: '+','.join(sorted(unknown)))
            contracts=[c for c in contracts if c['pattern_id'] in args.pattern_id]
        if not contracts:raise AcceptanceError('no matched targets')
        owner=json.loads(args.ownership_file.read_text())
        with gzip.open(out/'native-requests.jsonl.gz','wt',encoding='utf-8') as journal:
            db=Native(owner['endpoint'],journal)
            marker=db.run('MATCH (n:EveryPivotAcceptanceOwner) RETURN n.token AS token')
            if marker!=[{'token':owner['token']}]:raise AcceptanceError('task-owned database marker mismatch; refusing writes')
            summary['database']=db.run('CALL dbms.components() YIELD name, versions, edition RETURN name, versions, edition')
            if not any(r['name']=='Neo4j Kernel' and r['versions'][0].startswith('5.') for r in summary['database']):raise AcceptanceError('Neo4j 5.x required')
            db.run('CREATE INDEX everypivot_acceptance_id IF NOT EXISTS FOR (n:EveryPivotNode) ON (n.id)')
            for c in contracts:
                query=root/'adapters/neo4j/generated'/ (c['pattern_id']+'.cypher')
                body,params=executable(query.read_text())
                (out/(c['pattern_id']+'.body.cypher')).write_text(body)
                (out/(c['pattern_id']+'.parameters.json')).write_text(canonical(params))
                summary.setdefault('inputs',{})[str(query.relative_to(root))]=hashlib.sha256(query.read_bytes()).hexdigest()
                summary['results'].append(authored_case(root,db,body,c,out))
                cases=list(scenarios(c,args.high_cardinality))
                fixture=json.loads((root/c['fixture_path']).read_text())
                if params!=fixture['parameters']:raise AcceptanceError('shell parameter defaults differ from fixture')
                if c['pattern_id']=='CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES':
                    graph={k:copy.deepcopy(fixture[k]) for k in ['nodes','relationships']}
                    next(n for n in graph['nodes'] if n['id']==params['source_id'])['negative_node_list']=c['negative_lists'][0]
                    cases.append({'name':'authored-email-full-block','graph':graph,'parameters':params,'targets':[],'kind':'acceptance'})
                for case in cases:
                    result=run_case(db,body,c,case,out);summary['results'].append(result)
                    print(c['pattern_id'],case['name'],result['status'],flush=True)
                if not args.high_cardinality:summary['skips'].append(c['pattern_id']+': high cardinality not requested')
            db.reset()
            summary['fault_cases']=fault_cases(db)
            summary['final_graph']=db.snapshot()
        exitcode=int(any(r['status']=='fail' for r in summary['results']) or bool(summary['skips']))
    except Exception as e:
        summary['failure']=str(e)
    summary['exit_code']=exitcode
    (out/'summary.json').write_text(json.dumps(summary,indent=2))
    return exitcode

if __name__=='__main__':sys.exit(main())
