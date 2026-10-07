#!/usr/bin/env python3
"""Restore project backups into uniquely named scratch DBs; never overwrite live DBs."""
import subprocess,pathlib,uuid,json,os
root=pathlib.Path(__file__).resolve().parents[2]
container='pkbm-canvas-postgres-1';checks=[]
def run(*args,input=None):return subprocess.run(['docker','exec','-i',container,*args],input=input,check=True,capture_output=True).stdout
def sql(db,query):return run('psql','-U','postgres','-d',db,'-At','-c',query).decode().strip()
for db,tables in [('pkbm_development',['pkbms','people','pkbm_memberships','role_assignments','learning_plans','learning_plan_items','canvas_bindings','identity_accounts','identity_membership_links','identity_external_subjects','canvas_identity_links','canvas_management_links']),('canvas_development',['accounts','users','pseudonyms','account_users','courses','enrollments','assignments','submissions'])]:
 scratch='pkbm_5a_restore_'+uuid.uuid4().hex[:12];created=False
 try:
  backup=root/'var/backups'/('stage5a-'+db+'.dump');backup.parent.mkdir(parents=True,exist_ok=True)
  payload=run('pg_dump','-U','postgres','-Fc',db);backup.write_bytes(payload);os.chmod(backup,0o600)
  run('createdb','-U','postgres',scratch);created=True
  run('pg_restore','-U','postgres','-d',scratch,'--exit-on-error',input=payload)
  checks.append(dict(name=db+' full restore',passed=True))
  for table in tables:
   query='SELECT count(*)::text || \':\' || md5(coalesce(string_agg(row_to_json(t)::text,\'\' ORDER BY id),\'\')) FROM '+table+' t'
   original=sql(db,query);restored=sql(scratch,query)
   checks.append(dict(name=db+' '+table+' restored unchanged',passed=original==restored,row_count=int(original.split(':')[0])))
 finally:
  if created:run('dropdb','-U','postgres',scratch)
  checks.append(dict(name=db+' scratch database removed',passed=sql('postgres',"SELECT count(*) FROM pg_database WHERE datname='"+scratch+"'")=='0'))
result=dict(scope='full local dump/restore into isolated databases; selected domain tables row count and hash equality; not production recovery',passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),checks=checks)
(root/'docs/tahap5a-hasil-uji-restore.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));raise SystemExit(bool(result['failed']))
