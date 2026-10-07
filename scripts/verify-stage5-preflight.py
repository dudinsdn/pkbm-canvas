#!/usr/bin/env python3
"""Stage 5 checks that do not require a Canvas access credential."""
from pathlib import Path
import json, requests
ROOT=Path(__file__).resolve().parents[1]
env=dict(line.split('=',1) for line in (ROOT/'.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
base='http://127.0.0.1:3000'
checks=[]
def check(name,passed):
 checks.append({'name':name,'passed':bool(passed)})
 print(name, 'PASS' if passed else 'FAIL',flush=True)
clients={}
for tenant in ['DEMO-A','DEMO-B']:
 for role,key in [('pengelola','ADMIN'),('tutor','TUTOR'),('warga_belajar','WB')]:
  s=requests.Session()
  r=s.post(base+'/api/v1/session',json={'pkbm_code':tenant,'email':role+'@pkbm.local','password':env['PKBM_LOCAL_'+key+'_PASSWORD']},timeout=30)
  check(tenant+'_'+role+'_login',r.status_code==200)
  if r.status_code!=200: continue
  s.headers['Authorization']='Bearer '+r.json()['token'];clients[(tenant,role)]=s
  r=s.get(base+'/api/v1/integration',timeout=30)
  check(tenant+'_'+role+'_integration_scope',r.status_code==(200 if role=='pengelola' else 403))
  if role=='pengelola' and r.status_code==200:
   check(tenant+'_credential_not_serialized','credentials_encrypted' not in r.text and '"access_token":' not in r.text and 'lti_secret' not in r.text)
  for endpoint in ['/api/v1/integration/links']:
   check(tenant+'_'+role+'_course_links',s.get(base+endpoint,timeout=30).status_code==200)
  if role!='pengelola':
   for path,method,data in [('/api/v1/integration','PUT',{'access_token':'forbidden-test'}),('/api/v1/integration/jobs','POST',{'delivery_id':'00000000-0000-0000-0000-000000000000'}),('/api/v1/integration/resources','POST',{}),('/api/v1/integration/jobs/00000000-0000-0000-0000-000000000000/retry','POST',{})]:
    check(tenant+'_'+role+'_deny_'+path,s.request(method,base+path,json=data,timeout=30).status_code==403)
for path in ['/api/v1/integration','/api/v1/integration/links','/api/v1/integration/resources/00000000-0000-0000-0000-000000000000?delivery_id=00000000-0000-0000-0000-000000000000']:
 check('anonymous_denied_'+path,requests.get(base+path,timeout=30).status_code==401)
for data in [{},{'oauth_consumer_key':'unknown'},{'oauth_consumer_key':'unknown','oauth_signature':'forged'}]:
 check('invalid_lti_'+str(len(data)),requests.post(base+'/lti/launch',data=data,timeout=30).status_code==401)
check('invalid_lti_exchange',requests.post(base+'/api/v1/lti/exchange',json={'code':'invalid'},timeout=30).status_code==401)
check('missing_lti_exchange',requests.post(base+'/api/v1/lti/exchange',json={},timeout=30).status_code==401)
out=ROOT/'var/validation/stage5';out.mkdir(parents=True,exist_ok=True)
report={'scope':'preflight_only_no_canvas_token','checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks)}
(out/'preflight-results.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(bool(report['failed']))
