#!/usr/bin/env python3
"""Requested real local Canvas integration checks. Secrets remain in ignored files."""
from pathlib import Path
import requests,json,subprocess
ROOT=Path(__file__).resolve().parents[1];BASE='http://127.0.0.1:3000/api/v1'
ENV=dict(x.split('=',1) for x in (ROOT/'.env').read_text().splitlines() if '=' in x and not x.startswith('#'))
secret=json.loads((ROOT/'var/validation/stage5/temporary-token.json').read_text())
checks=[];clients={}
def check(name,ok):
 checks.append({'name':name,'passed':bool(ok)});print(name,'PASS' if ok else 'FAIL',flush=True)
 if not ok: raise AssertionError(name)
def call(s,path,method='GET',data=None): return s.request(method,BASE+path,json=data,timeout=60)
def worker():
 r=subprocess.run([str(ROOT/'scripts/compose'),'exec','-T','pkbm','bundle','exec','rails','runner','job=CanvasSyncRunner.run_one; puts(job ? {status:job.status,error:job.last_error,code:job.error_code}.to_json : "none")'],capture_output=True,text=True,timeout=240)
 print(r.stdout.strip(),flush=True)
 if r.returncode: print(r.stderr[-1500:]);raise RuntimeError('worker failed')
def run(s,delivery):
 r=call(s,'/integration/jobs','POST',{'delivery_id':delivery});check('enqueue',r.status_code==202);jid=r.json()['job']['id'];worker()
 st=call(s,'/integration').json();job=next(x for x in st['jobs'] if x['id']==jid)
 check('sync_completed',job['status']=='completed');return st
try:
 for tenant in ['DEMO-A','DEMO-B']:
  s=requests.Session();r=call(s,'/session','POST',{'pkbm_code':tenant,'email':'pengelola@pkbm.local','password':ENV['PKBM_LOCAL_ADMIN_PASSWORD']});check(tenant+'_login',r.status_code==200);s.headers['Authorization']='Bearer '+r.json()['token'];clients[tenant]=s
  r=call(s,'/integration','PUT',{'access_token':secret['token']});check(tenant+'_configure',r.status_code==200)
  deliveries=call(s,'/operations/deliveries').json()['records'];delivery=next(x for x in deliveries if x['status']=='active')
  resources=call(s,'/catalog/learning_resources?limit=100').json()['records']
  selected=False
  for resource in resources:
   r=call(s,'/integration/resources','POST',{'delivery_id':delivery['id'],'learning_resource_id':resource['id'],'note':'Pengujian Tahap 5 lokal'})
   if r.status_code==201: selected=True;break
  check(tenant+'_select_reference',selected)
  st=run(s,delivery['id']);before=sorted((x['object_kind'],x['local_key'],x['remote_id']) for x in st['bindings'])
  check(tenant+'_all_object_kinds',set(x[0] for x in before)==set(['account','course','section','user','enrollment','outcome','module','page','module_item','external_tool']))
  st=run(s,delivery['id']);after=sorted((x['object_kind'],x['local_key'],x['remote_id']) for x in st['bindings']);check(tenant+'_binding_idempotent',before==after)
finally:
 out=ROOT/'var/validation/stage5';(out/'integration-results.json').write_text(json.dumps({'checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks)},indent=2)+'\n')
