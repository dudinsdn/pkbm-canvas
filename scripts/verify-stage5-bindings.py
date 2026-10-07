#!/usr/bin/env python3
"""Real Canvas behavior, controlled partial failure, and signed LTI HTTP checks."""
from pathlib import Path
import requests,json,subprocess,uuid,time,hmac,hashlib,base64,urllib.parse,html,re
ROOT=Path(__file__).resolve().parents[1];BASE='http://127.0.0.1:3000';CB='http://127.0.0.1:8081'
env=dict(x.split('=',1) for x in (ROOT/'.env').read_text().splitlines() if '=' in x and not x.startswith('#'))
secret=json.loads((ROOT/'var/validation/stage5/temporary-token.json').read_text());cs=requests.Session();cs.headers['Authorization']='Bearer '+secret['token'];checks=[]
def check(n,v):
 checks.append({'name':n,'passed':bool(v)});print(n,'PASS' if v else 'FAIL',flush=True)
 if not v:raise AssertionError(n)
def api(s,p,m='GET',d=None):return s.request(m,BASE+'/api/v1'+p,json=d,timeout=60)
def login(t,role='pengelola'):
 s=requests.Session();key={'pengelola':'ADMIN','tutor':'TUTOR','warga_belajar':'WB'}[role];r=api(s,'/session','POST',{'pkbm_code':t,'email':role+'@pkbm.local','password':env['PKBM_LOCAL_'+key+'_PASSWORD']});r.raise_for_status();s.headers['Authorization']='Bearer '+r.json()['token'];return s
def ruby(code):
 r=subprocess.run([str(ROOT/'scripts/compose'),'exec','-T','pkbm','bundle','exec','rails','runner',code],text=True,capture_output=True,timeout=240)
 if r.returncode:raise RuntimeError('Rails verification failed: '+r.stderr[-600:])
 return r.stdout.strip()
def state(s):return api(s,'/integration').json()
def enqueue(s,d):
 r=api(s,'/integration/jobs','POST',{'delivery_id':d});r.raise_for_status();return r.json()['job']['id']
def work(s,j,code=None):
 ruby(code or f'CanvasSyncRunner.run_one("{j}")');return next(x for x in state(s)['jobs'] if x['id']==j)
def repeat(s,d):j=enqueue(s,d);check('repeat_completed',work(s,j)['status']=='completed');return state(s)
def remote(p,m='GET',d=None):r=cs.request(m,CB+'/api/v1'+p,json=d,timeout=60);r.raise_for_status();return r.json()
a=login('DEMO-A');b=login('DEMO-B');sa=state(a);sb=state(b)
da=next(x['local_key'] for x in sa['bindings'] if x['object_kind']=='course');db=next(x['local_key'] for x in sb['bindings'] if x['object_kind']=='course')
cid=next(x['remote_id'] for x in sa['bindings'] if x['object_kind']=='course');cbid=next(x['remote_id'] for x in sb['bindings'] if x['object_kind']=='course')
def counts():return {k:len(remote('/courses/'+cid+'/'+k)) for k in ['modules','pages','enrollments','external_tools']}
try:
 for tenant in ['DEMO-A','DEMO-B']:
  s=login(tenant);st=state(s);bindings=st['bindings'];course=next(x for x in bindings if x['object_kind']=='course');id=course['remote_id'];account=next(x for x in bindings if x['object_kind']=='account')['remote_id'];section=next(x for x in bindings if x['object_kind']=='section')['remote_id'];users={x['remote_id'] for x in bindings if x['object_kind']=='user'}
  check(tenant+'_course_account_binding',str(remote('/courses/'+id)['account_id'])==account)
  check(tenant+'_section_course_binding',str(remote('/sections/'+section)['course_id'])==id)
  enrollments=remote('/courses/'+id+'/enrollments');check(tenant+'_enrollment_bindings',len(enrollments)==2 and all(str(x['user_id']) in users and str(x['course_section_id'])==section and str(x['course_id'])==id and x['enrollment_state']=='active' for x in enrollments))
  page=next(x for x in bindings if x['object_kind']=='page');content=remote('/courses/'+id+'/pages/'+page['remote_id']);check(tenant+'_page_reference_and_warning',content['published'] and '/#resource=' in content['body'] and 'bukan' in content['body'])
  outcome=next(x for x in bindings if x['object_kind']=='outcome');check(tenant+'_outcome_vendor_binding',remote('/outcomes/'+outcome['remote_id'])['vendor_guid'].startswith('pkbm-'+st['instance']['pkbm_id']))
  module=next(x for x in bindings if x['object_kind']=='module');items=remote('/courses/'+id+'/modules/'+module['remote_id']+'/items');check(tenant+'_module_page_binding',len(items)==1 and items[0]['page_url']==page['remote_id'])
finally:
 (ROOT/'var/validation/stage5/binding-results.json').write_text(json.dumps({'checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks)},indent=2)+'\n')
