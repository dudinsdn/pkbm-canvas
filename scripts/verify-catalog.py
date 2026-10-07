#!/usr/bin/env python3
"""Explicit stage 1/2 verification. Temporary DB is owned and removed by this run."""
import hashlib,json,subprocess,uuid
from pathlib import Path
import requests
ROOT=Path(__file__).resolve().parents[1]
DATA=json.loads((ROOT/'apps/pkbm/db/seeds/catalog.json').read_text())['tables']
OUT=ROOT/'var/validation/stage12';OUT.mkdir(parents=True,exist_ok=True)
results=[]
def record(name,ok,detail=None):
 results.append(dict(check=name,passed=bool(ok),detail=detail));print(name, 'PASS' if ok else 'FAIL',flush=True)
 if not ok:raise AssertionError(name)
def sql(query,db='pkbm_development',admin=False,check=True):
 cmd=[str(ROOT/'scripts/compose'),'exec','-T','postgres']
 if admin:cmd+=['psql','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-Atq']
 else:cmd+=['sh','-c','PGPASSWORD="$PKBM_DB_PASSWORD" exec psql -h 127.0.0.1 -U pkbm -d "$1" -v ON_ERROR_STOP=1 -Atq','audit',db]
 r=subprocess.run(cmd,input=query,text=True,capture_output=True)
 if check and r.returncode:raise RuntimeError(r.stderr[-1200:])
 return r

def snapshot(db):
 return {t:sql(f"SELECT json_build_object('count',count(*),'digest',md5(COALESCE(string_agg(to_jsonb(t)::text,E'\\n' ORDER BY id),''))) FROM {t} t;",db).stdout.strip() for t in DATA}

def expected_error(name,statement,state,fragment=None,db='pkbm_development'):
 # psql verbose SQLSTATE supplies precise constraint class.
 q='\\set VERBOSITY verbose\nBEGIN;\n'+statement+'\nROLLBACK;'
 r=sql(q,db,check=False)
 record(name,r.returncode!=0 and state in r.stderr and (not fragment or fragment in r.stderr),{'sqlstate':state,'error':r.stderr[-400:]})

def uid():return str(uuid.uuid4())
def rid(table,key):return next(x['id'] for x in DATA[table] if x['catalog_key']==key)
def clone(table,changes,where='TRUE'):
 cols=list(DATA[table][0]);real=json.loads(sql(f"SELECT json_agg(column_name ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='public' AND table_name='{table}';").stdout)
 vals=[changes.get(c,'t.'+c) for c in real]
 return f"INSERT INTO {table} ({','.join(real)}) SELECT {','.join(vals)} FROM {table} t WHERE {where} LIMIT 1;"

try:
 before=snapshot('pkbm_development')
 (OUT/'before.json').write_text(json.dumps(before,indent=2)+'\n')
 for action in ['catalog-migrate','catalog-seed','catalog-seed']:
  r=subprocess.run([str(ROOT/'scripts/local'),action],text=True,capture_output=True)
  record('existing_'+action+'_'+str(len(results)),r.returncode==0,{'exit':r.returncode})
 record('existing_repeat_hashes_unchanged',snapshot('pkbm_development')==before)
 db='pkbm_catalog_audit_'+uuid.uuid4().hex[:10]
 sql(f'CREATE DATABASE {db} OWNER pkbm;',db='postgres',admin=True)
 try:
  for action in ['migrate','seed','migrate','seed']:
   emitted=subprocess.check_output([str(ROOT/'scripts/catalog-sql'),action],text=True)
   r=sql(emitted,db);record('fresh_'+action+'_'+str(len(results)),r.returncode==0)
  record('fresh_matches_existing',snapshot(db)==before)
  record('fresh_migration_once',sql('SELECT count(*) FROM schema_migrations;',db).stdout.strip()=='1')
  sql("UPDATE source_documents SET title=title || ' audit conflict' WHERE catalog_key='KUR-C';",db)
  changed=snapshot(db)
  emitted=subprocess.check_output([str(ROOT/'scripts/catalog-sql'),'seed'],text=True)
  rejected=sql(emitted,db,check=False)
  record('seed_changed_content_rejected',rejected.returncode!=0 and 'Seed content changed' in rejected.stderr)
  record('rejected_seed_transaction_unchanged',snapshot(db)==changed)
 finally:
  sql(f'DROP DATABASE {db};',db='postgres',admin=True)
  record('temporary_database_removed',True)
 record('canvas_pkbm_connect_isolated',sql("SELECT NOT has_database_privilege('pkbm','canvas_development','CONNECT') AND NOT has_database_privilege('canvas','pkbm_development','CONNECT');",admin=True).stdout.strip()=='t')
 expected_error('duplicate_catalog_key',clone('source_documents',{'id':f"'{uid()}'::uuid"}), '23505')
 expected_error('source_sha_invalid',"UPDATE source_documents SET sha256='invalid' WHERE catalog_key='KUR-C';",'23514')
 expected_error('reference_page_bounds',"UPDATE source_references SET pdf_page_end=9999 WHERE catalog_key=(SELECT catalog_key FROM source_references LIMIT 1);",'P0001','exceeds PDF')
 expected_error('reference_reverse_range',"UPDATE source_references SET pdf_page_end=pdf_page_start-1 WHERE pdf_page_start>1;",'23514')
 expected_error('foreign_key_missing',f"UPDATE source_references SET source_document_id='{uid()}' WHERE catalog_key=(SELECT catalog_key FROM source_references LIMIT 1);",'23503')
 expected_error('group_kind_invalid',"UPDATE curriculum_groups SET kind='modul' WHERE catalog_key='V:umum';",'23514')
 expected_error('skk_zero',"UPDATE curriculum_groups SET skk_budget=0 WHERE catalog_key='V:umum';",'23514')
 expected_error('subject_skk_negative',"UPDATE curriculum_components SET subject_skk=-1 WHERE catalog_key='V:MTK';",'23514')
 expected_error('target_parent_cross_component',f"UPDATE learning_targets SET parent_id='{rid('learning_targets','V:BID:KI3')}' WHERE catalog_key='V:MTK:3.1';",'23503')
 expected_error('target_parent_wrong_kind',f"UPDATE learning_targets SET parent_id='{rid('learning_targets','V:MTK:3.2')}' WHERE catalog_key='V:MTK:3.1';",'P0001','parent kind')
 expected_error('target_self_parent',"UPDATE learning_targets SET parent_id=id WHERE catalog_key='V:PEM:area-1';",'P0001','cycle')
 expected_error('target_parent_cycle',f"UPDATE learning_targets SET parent_id='{rid('learning_targets','V:PEM:area-2')}' WHERE catalog_key='V:PEM:area-1'; UPDATE learning_targets SET parent_id='{rid('learning_targets','V:PEM:area-1')}' WHERE catalog_key='V:PEM:area-2';",'P0001','cycle')
 expected_error('framework_target_cross_component',f"UPDATE framework_targets SET learning_target_id='{rid('learning_targets','V:BID:3.1')}' WHERE catalog_key='V:MTK:3.1';",'23503')
 expected_error('activity_target_cross_component',f"UPDATE framework_activity_targets SET learning_target_id='{rid('learning_targets','V:BID:3.1')}' WHERE catalog_key='V:MTK:1:3.1';",'P0001','component differ')
 expected_error('resource_unit_wrong_resource',f"UPDATE resource_target_mappings SET learning_resource_id='{rid('learning_resources','MOD-BID-V-01')}' WHERE catalog_key='MAP-01:3.1';",'23503')
 expected_error('mapping_cannot_prove_mastery',"UPDATE resource_target_mappings SET proves_learner_mastery=true WHERE catalog_key='MAP-01:3.1';",'23514')
 expected_error('source_rules_not_executable',"UPDATE source_policy_statements SET executable=true;",'23514')
 # repeated source codes are allowed when parent/context differs, as the source actually does.
 record('repeated_indicator_codes_preserved',sql("SELECT count(*) FROM learning_targets WHERE curriculum_component_id=(SELECT id FROM curriculum_components WHERE catalog_key='V:MTK') AND kind='indikator' AND source_code='3.2.2';").stdout.strip()=='2')
 version=uid(); track=uid()
 expected_error('component_track_wrong_version',f"INSERT INTO curriculum_versions(id,catalog_key,name,status,source_document_id) SELECT '{version}','audit-version','Audit','audit',source_document_id FROM curriculum_versions LIMIT 1; INSERT INTO specialization_tracks(id,catalog_key,curriculum_version_id,code,name) VALUES('{track}','audit-track','{version}','AUDIT','Audit'); UPDATE curriculum_components SET specialization_track_id='{track}' WHERE catalog_key='V:MTK';",'P0001','curriculum differ')
 record('all_subject_skk_unallocated',sql('SELECT count(*) FROM curriculum_components WHERE subject_skk IS NOT NULL;').stdout.strip()=='0')
 record('skk_group_budgets',json.loads(sql("SELECT json_object_agg(catalog_key,skk_budget) FROM curriculum_groups;").stdout)=={'V:umum':26,'V:peminatan':30,'V:khusus':24,'VI:umum':14,'VI:peminatan':15,'VI:khusus':13})
 record('negative_checks_leave_data_unchanged',snapshot('pkbm_development')==before)
 base='http://127.0.0.1:3000/api/v1/catalog'
 r=requests.get(base,timeout=30);r.raise_for_status();body=r.json()
 record('api_counts_match_seed',body['counts']=={t:len(rows) for t,rows in DATA.items()})
 record('api_coverage_exact',len(body['coverage'])==52 and any(x['coverage_status']=='struktur_saja' for x in body['coverage']) and body['academic_decisions_enabled'] is False)
 for t,rows in DATA.items():
  received=[];offset=0
  while True:
   page=requests.get(base+'/'+t,params={'limit':100,'offset':offset},timeout=30);page.raise_for_status();records=page.json()['records'];received+=records
   if len(records)<100:break
   offset+=100
  record('api_collection_'+t,{x['id'] for x in received}=={x['id'] for x in rows})
 record('api_limit_clamped',requests.get(base+'/learning_targets?limit=999&offset=-7',timeout=30).json()['limit']==100)
 record('api_unknown_collection_rejected',requests.get(base+'/people',timeout=30).status_code==404)
 record('api_write_not_exposed',requests.post(base+'/learning_targets',json={},timeout=30).status_code==404)
 record('final_catalog_hashes_unchanged',snapshot('pkbm_development')==before)
finally:
 (OUT/'database-api-results.json').write_text(json.dumps({'checks':results,'passed':sum(x['passed'] for x in results),'failed':sum(not x['passed'] for x in results)},ensure_ascii=False,indent=2)+'\n')
