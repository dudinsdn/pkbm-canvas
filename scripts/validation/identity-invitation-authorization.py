#!/usr/bin/env python3
"""Invitation guards against existing fixtures; never create or change an account."""
from pathlib import Path
exec(Path(__file__).with_name('manager-dashboard-api.py').read_text().split('checks=[]')[0])
checks=[];base='http://127.0.0.1:3000';sessions=[]
def check(name,status,expected):
 checks.append(dict(name=name,passed=status==expected,status=status,expected=expected))
def connect(username,password):
 s=Session();r=s.get(base+'/auth/login',timeout=40);f=next(f for f in Forms(r.text).forms if 'username' in f['fields'])
 s.post(urllib.parse.urljoin(r.url,f['action']),data=f['fields']|dict(username=username,password=password),timeout=40)
 ctx=s.get(base+'/api/v1/identity/contexts',timeout=30).json()['contexts'][0]
 token=s.post(base+'/api/v1/identity/context',json=ctx,headers={'Origin':base},timeout=30).json()['token']
 sessions.append((s,token));return s,token,ctx
try:
 a,at,ctx=connect('demo-a-pengelola',env['PKBM_LOCAL_ADMIN_PASSWORD'])
 payload=dict(membership_id=ctx['membership_id'],username='validation-forbidden')
 check('unauthenticated rejected',Session().post(base+'/api/v1/identity/invitations',json=payload,timeout=30).status_code,401)
 check('existing active identity cannot be relinked',a.post(base+'/api/v1/identity/invitations',json=payload,headers={'Authorization':'Bearer '+at},timeout=30).status_code,422)
 check('invalid username rejected',a.post(base+'/api/v1/identity/invitations',json=payload|dict(username='../invalid'),headers={'Authorization':'Bearer '+at},timeout=30).status_code,422)
 b,bt,_=connect('demo-b-pengelola',env['PKBM_LOCAL_ADMIN_PASSWORD'])
 check('foreign PKBM membership rejected',b.post(base+'/api/v1/identity/invitations',json=payload,headers={'Authorization':'Bearer '+bt},timeout=30).status_code,404)
 for role,key in [('tutor','TUTOR'),('warga-belajar','WB')]:
  s,token,_=connect('demo-a-'+role,env['PKBM_LOCAL_'+key+'_PASSWORD'])
  check(role+' cannot invite',s.post(base+'/api/v1/identity/invitations',json=payload,headers={'Authorization':'Bearer '+token},timeout=30).status_code,403)
finally:
 for s,token in sessions:
  r=s.post(base+'/api/v1/identity/logout',json={},headers={'Origin':base,'Authorization':'Bearer '+token},timeout=30)
  if r.status_code==200:s.get(r.json()['logout_url'],timeout=40)
result=dict(scope='HTTP invitation authorization using existing demo fixtures; only rejected writes; no account created or altered',passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),checks=checks)
(root/'docs/tahap5a-hasil-uji-otorisasi-undangan.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));raise SystemExit(bool(result['failed']))
