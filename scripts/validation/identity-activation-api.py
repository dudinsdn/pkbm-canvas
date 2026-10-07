#!/usr/bin/env python3
"""Local activation/reset via mail sink. Creates one explicitly named test profile."""
import secrets,subprocess,email,email.policy,re,time
from pathlib import Path
exec((Path(__file__).with_name('manager-dashboard-api.py')).read_text().split('checks=[]')[0])
checks=[];base='http://127.0.0.1:3000';user='validation-'+secrets.token_hex(6);password=secrets.token_hex(24)
def check(name,ok,detail=None):checks.append(dict(name=name,passed=bool(ok),detail=detail));print(name,'PASS' if ok else 'FAIL',detail or '',flush=True)
def login(session,username,password):
 r=session.get(base+'/auth/login',timeout=40);forms=Forms(r.text).forms
 if any('username' in f['fields'] for f in forms):
  f=next(f for f in forms if 'username' in f['fields']);r=session.post(urllib.parse.urljoin(r.url,f['action']),data=f['fields']|dict(username=username,password=password),timeout=40)
 return r
def logout(session,token=None):
 r=session.post(base+'/api/v1/identity/logout',json={},headers={'Origin':base,**({'Authorization':'Bearer '+token} if token else {})},timeout=30)
 if r.status_code==200:session.get(r.json()['logout_url'],timeout=40)
def mail_link():
 for attempt in range(10):
  raw=subprocess.check_output(['docker','exec','pkbm-canvas-pkbm-1','ruby','-rjson','-e',"puts Dir['tmp/identity-mail/*.json'].sort_by { |p| File.mtime(p) }.map { |p| JSON.parse(File.read(p)) }.select { |m| m['recipients'].any? { |r| r.include?(ARGV[0]) } }.to_json",user+'@pkbm.local'])
  mails=json.loads(raw)
  if mails:
   newest=mails[-1];msg=email.message_from_string(newest['body'],policy=email.policy.default)
   content='\n'.join(part.get_content() for part in msg.walk() if part.get_content_type() in ['text/plain','text/html'])
   links=re.findall(r'https?://[^\s<>"\']+',content)
   link=next((x.replace('&amp;','&') for x in links if 'action-token' in x),None)
   if link:return link
  time.sleep(.5)
 raise RuntimeError('No local mail link')
def actions(session,url,new_password):
 r=session.get(url,timeout=40)
 for attempt in range(8):
  forms=Forms(r.text).forms
  if not forms:
   links=re.findall(r'href="([^"]+)"',r.text)
   proceed=next((x for x in links if '/login-actions/action-token?' in x),None)
   if proceed:
    target=urllib.parse.urljoin(r.url,proceed.replace('&amp;','&'))
    if urllib.parse.urlparse(target).netloc!='127.0.0.1:8082':raise RuntimeError('Unexpected identity action origin')
    r=session.get(target,timeout=40);continue
   return_link=next((x for x in links if x.rstrip('/')==base),None)
   if return_link:return session.get(return_link,timeout=40)
   return r
  f=forms[0];fields=f['fields'].copy()
  for name in fields:
   if 'password' in name:fields[name]=new_password
  if 'lastName' in fields and not fields['lastName']:raise RuntimeError('Surname still required')
  if not any('password' in name for name in fields):fields['accept']='true'
  r=session.post(urllib.parse.urljoin(r.url,f['action']),data=fields,timeout=40)
  if urllib.parse.urlparse(r.url).netloc=='127.0.0.1:3000':return r
 return r
manager=Session();fixture=Session();token=None
try:
 login(manager,'demo-a-pengelola',env['PKBM_LOCAL_ADMIN_PASSWORD']);ctx=manager.get(base+'/api/v1/identity/contexts',timeout=30).json()['contexts'][0]
 token=manager.post(base+'/api/v1/identity/context',json=ctx,headers={'Origin':base},timeout=30).json()['token'];headers={'Authorization':'Bearer '+token}
 def create(table,data):
  r=manager.post(base+'/api/v1/operations/'+table,json={'record':data},headers=headers,timeout=30);r.raise_for_status();return r.json()
 person=create('people',dict(name='Local activation validation',email=user+'@pkbm.local'));member=create('pkbm_memberships',dict(person_id=person['id']));create('role_assignments',dict(membership_id=member['id'],role='warga_belajar'))
 payload=dict(membership_id=member['id'],username=user)
 r=Session().post(base+'/api/v1/identity/invitations',json=payload,timeout=30);check('unauthenticated invitation rejected',r.status_code==401,r.status_code)
 r=manager.post(base+'/api/v1/identity/invitations',json=payload,headers=headers,timeout=40);check('manager invitation accepted',r.status_code==202,r.status_code)
 if r.status_code!=202:raise RuntimeError(r.json().get('error','Invitation failed'))
 link=mail_link();check('activation delivered only to local sink',bool(link));r=actions(fixture,link,password);check('activation action completion',r.status_code==200 and urllib.parse.urlparse(r.url).netloc=='127.0.0.1:3000',{'status':r.status_code,'path':urllib.parse.urlparse(r.url).path})
 login(fixture,user,password);r=fixture.get(base+'/api/v1/identity/contexts',timeout=30);check('activated identity can login',r.status_code==200 and any(x['membership_id']==member['id'] for x in r.json().get('contexts',[])),r.status_code)
 r=manager.post(base+'/api/v1/identity/invitations',json=payload,headers=headers,timeout=30);check('active identity reinvitation rejected',r.status_code==422,r.status_code)
 logout(fixture)
 r=fixture.get(base+'/auth/login',timeout=30);links=re.findall(r'href="([^"]*reset-credentials[^"]*)"',r.text);check('central forgot password link',bool(links))
 if not links:raise RuntimeError('Reset form missing')
 r=fixture.get(urllib.parse.urljoin(r.url,links[0].replace('&amp;','&')),timeout=30);f=Forms(r.text).forms[0]
 r=fixture.post(urllib.parse.urljoin(r.url,f['action']),data=f['fields']|{'username':user},timeout=40)
 # Read latest recipient message by selecting action-token distinct from activation.
 time.sleep(.5);new_password=secrets.token_hex(24);reset_link=mail_link();check('reset email delivered',reset_link!=link)
 r=actions(fixture,reset_link,new_password);check('reset action completed',r.status_code==200,r.status_code)
 logout(fixture);login(fixture,user,new_password);r=fixture.get(base+'/api/v1/identity/contexts',timeout=30);check('new central password works',r.status_code==200,r.status_code)
 logout(fixture);r=login(fixture,user,password);check('previous password rejected',fixture.get(base+'/api/v1/identity/contexts',timeout=30).status_code==401)
except Exception as error:check('activation/reset protocol completion',False,type(error).__name__)
finally:
 logout(manager,token);logout(fixture)
result=dict(scope='local HTTP activation/reset with disposable named profile and internal SMTP receiver; test profile retained for audit; no real-user password changed',fixture_username=user,passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),checks=checks)
(root/'docs/tahap5a-hasil-uji-aktivasi.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k] for k in ['passed','failed']}));raise SystemExit(bool(result['failed']))
