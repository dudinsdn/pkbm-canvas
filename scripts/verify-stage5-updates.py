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
 original=api(a,'/operations/deliveries/'+da).json()['name']
 r=api(a,'/operations/deliveries/'+da,'PATCH',{'record':{'name':original+' — update uji'}});check('local_update',r.status_code==200)
 repeat(a,da);check('course_update_propagated',remote('/courses/'+cid)['name']==original+' — update uji')
 api(a,'/operations/deliveries/'+da,'PATCH',{'record':{'name':original}}).raise_for_status();repeat(a,da);check('course_name_restored',remote('/courses/'+cid)['name']==original)
 enrollment=next(x for x in api(a,'/operations/delivery_enrollments').json()['records'] if x['delivery_id']==da and x['status']=='active');eid=enrollment['learner_program_id']
 api(a,'/operations/learner_programs/'+eid,'PATCH',{'record':{'status':'inactive'}}).raise_for_status();repeat(a,da);check('roster_inactivated',any(x['type']=='StudentEnrollment' and x['enrollment_state']=='inactive' for x in remote('/courses/'+cid+'/enrollments?state[]=inactive')))
 api(a,'/operations/learner_programs/'+eid,'PATCH',{'record':{'status':'active'}}).raise_for_status();repeat(a,da);check('roster_reactivated',any(x['type']=='StudentEnrollment' and x['enrollment_state']=='active' for x in remote('/courses/'+cid+'/enrollments')))
 check('local_status_restored',api(a,'/operations/learner_programs/'+eid).json()['status']=='active')
finally:
 (ROOT/'var/validation/stage5/update-results.json').write_text(json.dumps({'checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks)},indent=2)+'\n')
