#!/usr/bin/env python3
import copy,io,json,pathlib,tempfile,unittest
from unittest.mock import patch
from accept_neo4j_query_profiles import *

class HarnessTests(unittest.TestCase):
    def setUp(self):
        root=pathlib.Path(__file__).resolve().parent.parent
        self.c=json.loads((root/'fixtures/query-profiles/neo4j/acceptance/OSINT_SSH_HOSTKEY_CLUSTER.json').read_text())
        self.record=records(self.c,'source',['target'])[0]
    def test_identifier_only_in_caveat(self):
        bad=copy.deepcopy(self.record);bad['target']='wrong';bad['caveats'].append('target')
        with self.assertRaises(AcceptanceError):compare([bad],[self.record])
    def test_extra_target(self):
        extra=copy.deepcopy(self.record);extra['target']='extra'
        with self.assertRaises(AcceptanceError):compare([self.record,extra],[self.record])
    def test_missing_malformed_and_wrong_values(self):
        for bad in [None,{},'target',{**self.record,'relation':'wrong'},{**self.record,'confidence':1},{**self.record,'features':{**self.record['features'],'path_length':True}},{**self.record,'evidence_paths':[['target','PRESENTED_BY','source']]}]:
            with self.subTest(bad=bad),self.assertRaises(AcceptanceError):compare([bad],[self.record])
        with self.assertRaises(AcceptanceError):compare([],[self.record])
    def test_invalid_input_still_checks_evidence_boundary(self):
        graph,targets=scenario_graph(self.c)
        case={'graph':graph,'parameters':{'source_id':'acceptance:source'}}
        good=records(self.c,'acceptance:source',targets)
        validate_observed_records(good,self.c,case)
        for bad in [[{'confidence':1}],[dict(good[0],confidence=1)],[dict(good[0],source='wrong')]]:
            with self.assertRaises(AcceptanceError):validate_observed_records(bad,self.c,case)
    def test_authored_failure_is_recorded(self):
        from unittest.mock import Mock
        db=Mock();db.reset.side_effect=AcceptanceError('injected load failure')
        root=pathlib.Path(__file__).resolve().parent.parent
        with tempfile.TemporaryDirectory() as d:
            result=authored_case(root,db,'RETURN 1',self.c,pathlib.Path(d))
            self.assertEqual(result['status'],'fail')
            proof=json.load(gzip.open(next(pathlib.Path(d).glob('*.gz'))))
            self.assertIn('injected load failure',proof['failure'])
    def test_exact_result_columns(self):
        with self.assertRaises(AcceptanceError):
            traversals([{'everypivot_traversal':self.record,'confidence':1}])
        self.assertEqual(traversals([{'everypivot_traversal':self.record}]),[self.record])
    def test_null_and_omitted_parameters_distinct(self):
        cases={c['name']:c for c in scenarios(self.c,False)}
        self.assertIsNone(cases['as_of-null']['parameters']['as_of'])
        self.assertNotIn('as_of',cases['as_of-omitted']['parameters'])
    def test_full_state_captures_other_labels(self):
        db=Native('http://127.0.0.1:17474/db/neo4j/tx/commit',io.StringIO())
        with patch.object(db,'run',side_effect=[[{'identity':'1','labels':['Other'],'properties':{}}],[]]) as run:
            state=db.state()
            self.assertEqual(state['nodes'][0]['labels'],['Other'])
            self.assertIn('MATCH (n)',run.call_args_list[0].args[0])
    def test_no_matched_targets(self):
        import subprocess,sys
        with tempfile.TemporaryDirectory() as d:
            output=pathlib.Path(d)/'out'
            r=subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('accept_neo4j_query_profiles.py')),'--ownership-file',str(pathlib.Path(d)/'absent'),'--output',str(output),'--pattern-id','UNKNOWN'],capture_output=True,text=True)
            self.assertEqual(r.returncode,1)
            self.assertIn('no matched targets',json.loads((output/'summary.json').read_text())['failure'])
    def test_missing_shell_dependency(self):
        import subprocess
        root=pathlib.Path(__file__).resolve().parent.parent
        r=subprocess.run(['ruby',str(root/'tools/smoke_neo4j_query_profiles.rb'),'--cypher-shell','/nonexistent-everypivot-cypher-shell'],capture_output=True,text=True)
        self.assertEqual(r.returncode,1)
        self.assertIn('executable not found',r.stderr)
    def test_multiplicity(self):
        with self.assertRaises(AcceptanceError):compare([self.record]*2,[self.record])
        compare([self.record]*2,[self.record]*2)
    def test_accidentally_empty_graph_even_zero_expected(self):
        g,_=scenario_graph(self.c)
        with self.assertRaises(AcceptanceError):check_graph({'nodes':[],'relationships':[]},g)
    def test_strict_dates(self):
        self.assertEqual(date_input('2024-02-29'),dt.date(2024,2,29))
        for bad in [None,20240229,'20240229','2023-02-29','2024-2-29','2024-02-29T00:00:00Z','']:
            with self.subTest(bad=bad),self.assertRaises(AcceptanceError):date_input(bad)
    def test_directive_removal_preserves_body(self):
        text="// keep\n:param source_id => 'a\\\'b';\nWITH $source_id AS s\nRETURN s;\n"
        body,params=executable(text)
        self.assertEqual(body,'// keep\nWITH $source_id AS s\nRETURN s;\n');self.assertEqual(params,{'source_id':"a'b"})
        with self.assertRaises(AcceptanceError):executable(':source unexpected\nRETURN 1;')
    def test_loader_split_quoted_semicolon(self):
        self.assertEqual(len(statements("RETURN 'a;b';\nRETURN 2;")),2)
    def test_graph_properties_direction_and_duplicates(self):
        g,_=scenario_graph(self.c)
        for key in ['nodes','relationships']:
            bad=copy.deepcopy(g);bad[key]=[]
            with self.assertRaises(AcceptanceError):check_graph(bad,g)
        bad=copy.deepcopy(g);bad['relationships']*=2
        with self.assertRaises(AcceptanceError):check_graph(bad,g)
    def test_no_remote_endpoint(self):
        for url in ['http://example.com/db/neo4j/tx/commit','http://127.0.0.1/db/user/tx/commit']:
            with self.assertRaises(AcceptanceError):Native(url,io.StringIO())

if __name__=='__main__':unittest.main()
