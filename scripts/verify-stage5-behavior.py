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
 check('distinct_canvas_accounts',next(x['remote_id'] for x in sa['bindings'] if x['object_kind']=='account')!=next(x['remote_id'] for x in sb['bindings'] if x['object_kind']=='account'))
 check('distinct_canvas_courses',cid!=cbid)
 for role in ['pengelola','tutor','warga_belajar']:
  s=login('DEMO-A',role);links=api(s,'/integration/links').json()['courses'];check(role+'_only_own_course',any(x['canvas_course_id']==cid for x in links) and all(x['canvas_course_id']!=cbid for x in links))
  for selected in sa['resources']:
   if selected['delivery_id']!=da:continue
   r=api(s,'/integration/resources/'+selected['learning_resource_id']+'?delivery_id='+da)
   check(role+'_pdf_bytes',r.status_code==200 and r.content.startswith(b'%PDF-'))
  foreign=sb['resources'][0];check(role+'_foreign_pdf_denied',api(s,'/integration/resources/'+foreign['learning_resource_id']+'?delivery_id='+db).status_code==404)
 check('foreign_delivery_enqueue_denied',api(a,'/integration/jobs','POST',{'delivery_id':db}).status_code==404)
 check('foreign_job_retry_denied',api(a,'/integration/jobs/'+sb['jobs'][0]['id']+'/retry','POST',{}).status_code==404)
 check('foreign_resource_selection_denied',api(a,'/integration/resources','POST',{'delivery_id':db,'learning_resource_id':sb['resources'][0]['learning_resource_id']}).status_code==404)
 before=counts();repeat(a,da);check('remote_counts_idempotent',counts()==before)
 # Remote conflict, ordinary retry, explicit local overwrite.
 original=remote('/courses/'+cid)['name'];remote('/courses/'+cid,'PUT',{'course':{'name':original+' — konflik uji'}})
 j=enqueue(a,da);check('remote_conflict_detected',work(a,j)['status']=='conflict')
 api(a,'/integration/jobs/'+j+'/retry','POST',{}).raise_for_status();check('normal_retry_preserves_conflict',work(a,j)['status']=='conflict')
 api(a,'/integration/jobs/'+j+'/retry','POST',{'force_local':True}).raise_for_status();check('forced_retry_completed',work(a,j)['status']=='completed');check('local_name_restored',remote('/courses/'+cid)['name']==original)
 # Recovery after a real remote PUT succeeded but local binding persistence failed.
 mb=next(x for x in state(a)['bindings'] if x['object_kind']=='module' and x['local_key']==da)
 ruby(f'CanvasBinding.find("{mb["id"]}").destroy!')
 j=enqueue(a,da)
 injection=f'''CanvasApi.prepend(Module.new do
 def request(method,path,*args,**kwargs)
  result=super
  if method=="PUT" && path=="/api/v1/courses/{cid}/modules/{mb['remote_id']}"
   raise CanvasApi::Error.new(0,"Fault injection setelah PUT remote sebelum binding")
  end
  result
 end
end); CanvasSyncRunner.run_one("{j}")'''
 check('partial_failure_recorded',work(a,j,injection)['status']=='failed')
 api(a,'/integration/jobs/'+j+'/retry','POST',{}).raise_for_status();check('partial_failure_retry_completed',work(a,j)['status']=='completed')
 recovered=next(x for x in state(a)['bindings'] if x['object_kind']=='module' and x['local_key']==da);check('recovery_same_remote_id',recovered['remote_id']==mb['remote_id']);check('recovery_no_remote_duplicates',counts()==before)
 # Secret checks and cryptographic LTI tests. Secrets are captured, never printed.
 info=json.loads(ruby('i=CanvasInstance.first; puts({id:i.id,pkbm_id:i.pkbm_id,key:i.consumer_key,secret:i.credentials.fetch("lti_secret"),encrypted:!i.credentials_encrypted.include?(i.credentials.fetch("access_token"))}.to_json)'))
 check('credential_ciphertext_not_plaintext',info['encrypted'])
 members=api(a,'/operations/pkbm_memberships').json()['records'];wb=login('DEMO-A','warga_belajar');mid=api(wb,'/me').json()['membership_id'];person=next(x['person_id'] for x in members if x['id']==mid)
 uid=next(x['remote_id'] for x in state(a)['bindings'] if x['object_kind']=='user' and x['local_key']==person)
 def signed(**extra):
  values={'oauth_consumer_key':info['key'],'oauth_signature_method':'HMAC-SHA1','oauth_version':'1.0','oauth_nonce':uuid.uuid4().hex,'oauth_timestamp':str(int(time.time())),'lti_version':'LTI-1p0','lti_message_type':'basic-lti-launch-request','custom_canvas_user_id':uid,'custom_canvas_course_id':cid,'roles':'Administrator','resource_link_id':'uji * ~ +'};values.update(extra)
  enc=lambda v:urllib.parse.quote(str(v),safe='~-._');norm='&'.join(k+'='+v for k,v in sorted((enc(k),enc(v)) for k,v in values.items()));msg='POST&'+enc(BASE+'/lti/launch')+'&'+enc(norm);values['oauth_signature']=base64.b64encode(hmac.new((enc(info['secret'])+'&').encode(),msg.encode(),hashlib.sha1).digest()).decode();return values
 def launch(v):return requests.post(BASE+'/lti/launch',data=v,allow_redirects=False,timeout=60)
 values=signed();r=launch(values);check('signed_lti_positive',r.status_code==303);code=r.headers['Location'].split('lti_code=')[1]
 r=requests.post(BASE+'/api/v1/lti/exchange',json={'code':code},timeout=60);check('one_time_exchange',r.status_code==200);s=requests.Session();s.headers['Authorization']='Bearer '+r.json()['token'];identity=api(s,'/me').json();check('forged_role_ignored',identity['membership_id']==mid and identity['roles']==['warga_belajar'])
 check('nonce_replay_denied',launch(values).status_code==401);check('code_replay_denied',requests.post(BASE+'/api/v1/lti/exchange',json={'code':code},timeout=60).status_code==401)
 for name,values in [('expired',signed(oauth_timestamp=str(int(time.time())-600))),('foreign_course',signed(custom_canvas_course_id=cbid)),('unknown_user',signed(custom_canvas_user_id='999999')),('wrong_signature',dict(signed(),oauth_signature='invalid'))]:check('lti_'+name+'_denied',launch(values).status_code==401)
 # Request Canvas's actual signed launch HTML through its authenticated HTTP route.
 ns={'__file__':str(ROOT/'scripts/validate-runtime.py')};exec((ROOT/'scripts/validate-runtime.py').read_text().split("results = {'roles': {}}")[0],ns);session,_=ns['login']('CANVAS_LMS_ADMIN');tool=next(x['remote_id'] for x in state(a)['bindings'] if x['object_kind']=='external_tool' and x['local_key']==da)
 session.post(CB+'/users/'+uid+'/masquerade',timeout=60).raise_for_status()
 r=session.get(CB+'/courses/'+cid+'/external_tools/'+tool,params={'as_user_id':uid},timeout=60);r.raise_for_status()
 from bs4 import BeautifulSoup
 soup=BeautifulSoup(r.text,'html.parser');form=next((f for f in soup.find_all('form') if f.get('action')==BASE+'/lti/launch'),None)
 check('canvas_generated_launch_form',form is not None)
 fields={x['name']:x.get('value','') for x in form.find_all('input') if x.get('name')};r=launch(fields);check('actual_canvas_signed_launch',r.status_code==303)
 code=r.headers['Location'].split('lti_code=')[1];ex=requests.post(BASE+'/api/v1/lti/exchange',json={'code':code},timeout=60);check('actual_canvas_exchange',ex.status_code==200);actual=requests.Session();actual.headers['Authorization']='Bearer '+ex.json()['token'];check('actual_canvas_identity',api(actual,'/me').json()['membership_id']==mid)
except Exception:
 raise
finally:
 out=ROOT/'var/validation/stage5/behavior-results.json';out.write_text(json.dumps({'checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks),'partial_failure':'controlled fault after actual Canvas PUT, before local binding save','lti_transport':'HTTP; browser rendering not claimed'},indent=2)+'\n')
