#!/usr/bin/env python3
"""HTTP protocol checks with isolated cookies; no browser UI proof or admin token."""
import re,json,pathlib,html.parser,urllib.parse,requests
ROOT=pathlib.Path(__file__).resolve().parents[2]
ENV=dict(line.split('=',1) for line in (ROOT/'.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
BASE='http://127.0.0.1:3000'
class Forms(html.parser.HTMLParser):
 def __init__(self,body):
  super().__init__();self.forms=[];self.current=None;self.feed(body)
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='form':self.current={'action':a.get('action',''),'fields':{}};self.forms.append(self.current)
  if tag=='input' and self.current is not None and a.get('name'):self.current['fields'][a['name']]=a.get('value','')
 def handle_endtag(self,tag):
  if tag=='form':self.current=None
class LoopbackSession(requests.Session):
 # Browser secure-cookie exceptions for loopback HTTP are absent in requests.
 # Emulate only the isolated 127.0.0.1 development transport, not public hosts.
 def prepare_request(self,request):
  if urllib.parse.urlparse(request.url).hostname=='127.0.0.1':
   for cookie in self.cookies:
    if cookie.domain=='127.0.0.1':cookie.secure=False
  return super().prepare_request(request)
checks=[]
def check(name,ok,detail=None):
 checks.append(dict(name=name,passed=bool(ok),detail=detail));print(name, 'PASS' if ok else 'FAIL',flush=True)
metadata=requests.get('http://127.0.0.1:8082/realms/pkbm/.well-known/openid-configuration',timeout=20)
check('OIDC discovery issuer',metadata.status_code==200 and metadata.json().get('issuer')=='http://127.0.0.1:8082/realms/pkbm')
check('portal SSO enabled',requests.get(BASE+'/api/v1/identity/configuration',timeout=20).json().get('enabled') is True)
configuration=requests.get('http://localhost:3000/api/v1/identity/configuration',timeout=20)
check('localhost configuration has canonical origin',configuration.status_code==200 and configuration.json().get('canonical_base_url')==BASE)
for collection in 'curriculum_versions curriculum_levels specialization_tracks curriculum_components learning_targets learning_resources'.split():
 response=requests.get(BASE+'/api/v1/catalog/'+collection+'?limit=100',timeout=20)
 check('UI catalog '+collection,response.status_code==200 and isinstance(response.json().get('records'),list),response.status_code)
for asset in ['pkbm.js','integration.js','assessments.js']:
 response=requests.get(BASE+'/assets/'+asset,timeout=20)
 check('served asset '+asset,response.status_code==200 and response.content==(ROOT/'apps/pkbm/public/assets'/asset).read_bytes())

for tenant in ['demo-a','demo-b']:
 for role,key in [('pengelola','ADMIN'),('tutor','TUTOR'),('warga-belajar','WB')]:
  username=tenant+'-'+role;s=LoopbackSession();token=None
  try:
   response=s.get(BASE+'/auth/login',timeout=30)
   form=next((f for f in Forms(response.text).forms if 'username' in f['fields']),None)
   check(username+' login form',form is not None,response.status_code)
   if not form:continue
   fields=form['fields']|{'username':username,'password':ENV['PKBM_LOCAL_'+key+'_PASSWORD']}
   response=s.post(urllib.parse.urljoin(response.url,form['action']),data=fields,timeout=30)
   contexts=s.get(BASE+'/api/v1/identity/contexts',timeout=30)
   check(username+' authenticated callback',contexts.status_code==200,{'callback_status':response.status_code,'contexts_status':contexts.status_code,'response_path':urllib.parse.urlparse(response.url).path,'error_text':re.sub('<[^>]+>',' ',response.text[response.text.find('id="kc-error-message"'):])[:450] if 'id="kc-error-message"' in response.text else None,'forms':[{ 'action_path':urllib.parse.urlparse(f['action']).path,'fields':list(f['fields'])} for f in Forms(response.text).forms]})
   if contexts.status_code!=200:continue
   rows=contexts.json().get('contexts',[]);check(username+' one tenant context',len(rows)==1)
   if len(rows)!=1:continue
   context=s.post(BASE+'/api/v1/identity/context',json=rows[0],headers={'Origin':BASE},timeout=20)
   check(username+' select context',context.status_code==200)
   if context.status_code!=200:continue
   token=context.json()['token'];headers={'Authorization':'Bearer '+token}
   me=s.get(BASE+'/api/v1/me',headers=headers,timeout=20)
   check(username+' role and tenant scope',me.status_code==200 and role.replace('-','_') in me.json().get('roles',[]) and me.json().get('pkbm_id')==rows[0]['pkbm_id'])
   collections='people pkbm_memberships role_assignments program_offerings learner_programs learning_groups group_memberships learning_design_versions design_components learning_activities activity_targets deliveries delivery_staff delivery_enrollments learning_plans learning_plan_items learning_sessions'.split()
   for collection in collections:
    records=s.get(BASE+'/api/v1/operations/'+collection,headers=headers,timeout=20)
    payload=records.json() if records.status_code==200 else {}
    check(username+' operations '+collection,records.status_code==200 and isinstance(payload.get('records'),list) and all(row.get('pkbm_id')==rows[0]['pkbm_id'] for row in payload.get('records',[])),records.status_code)
   assessments=s.get(BASE+'/api/v1/assessments',headers=headers,timeout=20)
   check(username+' assessments API',assessments.status_code==200 and all(plan.get('pkbm_id')==rows[0]['pkbm_id'] for plan in assessments.json().get('plans',[])),assessments.status_code)
   integration=s.get(BASE+'/api/v1/integration',headers=headers,timeout=20)
   check(username+' integration role guard',integration.status_code==(200 if role=='pengelola' else 403),integration.status_code)
   mapping=json.loads((ROOT/'var/identity/demo-mapping.json').read_text())
   other=next(row for row in mapping if row['tenant_code'].lower()!=tenant)
   foreign=s.get(BASE+'/api/v1/operations/pkbm_memberships/'+other['membership_id'],headers=headers,timeout=20)
   check(username+' other PKBM membership denied',foreign.status_code in [403,404],foreign.status_code)
   links=s.get(BASE+'/api/v1/integration/links',headers=headers,timeout=20)
   check(username+' course links API',links.status_code==200)
   if role!='pengelola' and links.status_code==200:
    courses=links.json().get('courses',[]);check(username+' ready course',bool(courses) and all(c.get('url','').startswith('/belajar/') for c in courses))
    if courses and courses[0].get('url'):
     course=s.get(BASE+courses[0]['url'],timeout=30)
     profile=s.get('http://127.0.0.1:8081/api/v1/users/self/profile',timeout=30)
     expected={('demo-a','tutor'):4,('demo-a','warga-belajar'):5,('demo-b','tutor'):6,('demo-b','warga-belajar'):7}[(tenant,role)]
     check(username+' Canvas session correct user',profile.status_code==200 and profile.json().get('id')==expected,{'course_status':course.status_code,'profile_status':profile.status_code})
     foreign_course=s.get('http://127.0.0.1:8081/api/v1/courses/'+('4' if tenant=='demo-a' else '3'),timeout=30)
     check(username+' other PKBM Canvas course denied',foreign_course.status_code in [401,403,404],foreign_course.status_code)
     check(username+' course access',course.status_code==200 and '/courses/' in course.url, {'final_path':urllib.parse.urlparse(course.url).path,'status':course.status_code})
   # Keep the original API session alive while creating another same-IdP session.
   # Local logout revokes only the new cookie, so the old token tests backchannel.
   renewed=s.get(BASE+'/auth/login',timeout=30)
   check(username+' repeated SSO without password',s.get(BASE+'/api/v1/identity/contexts',timeout=20).status_code==200 and urllib.parse.urlparse(renewed.url).netloc=='127.0.0.1:3000')
   logout=s.post(BASE+'/api/v1/identity/logout',json={},headers={'Origin':BASE},timeout=20)
   check(username+' portal logout API',logout.status_code==200)
   if logout.status_code==200:
    response=s.get(logout.json()['logout_url'],timeout=30)
    forms=Forms(response.text).forms
    check(username+' portal logout directly reaches login',any('username' in f['fields'] for f in forms))
    logout_fields=[list(f['fields']) for f in forms]
    for form in forms:
     if 'logout' in form['action']:
      response=s.post(urllib.parse.urljoin(response.url,form['action']),data=form['fields'],timeout=30);break
   check(username+' IdP logout completed',urllib.parse.urlparse(response.url).netloc=='127.0.0.1:8082' and any('username' in f['fields'] for f in Forms(response.text).forms),{'final_path':urllib.parse.urlparse(response.url).path,'form_fields':logout_fields if logout.status_code==200 else []})
   check(username+' older portal token revoked by backchannel',s.get(BASE+'/api/v1/me',headers=headers,timeout=20).status_code==401)
   if role!='pengelola':check(username+' Canvas session revoked by IdP',s.get('http://127.0.0.1:8081/api/v1/users/self/profile',timeout=30).status_code==401)
   if role!='pengelola':
    response=s.get(BASE+'/auth/login',timeout=30)
    form=next(f for f in Forms(response.text).forms if 'username' in f['fields'])
    s.post(urllib.parse.urljoin(response.url,form['action']),data=form['fields']|{'username':username,'password':ENV['PKBM_LOCAL_'+key+'_PASSWORD']},timeout=30)
    rows=s.get(BASE+'/api/v1/identity/contexts',timeout=20).json()['contexts']
    fresh=s.post(BASE+'/api/v1/identity/context',json=rows[0],headers={'Origin':BASE},timeout=20).json()['token']
    s.get(BASE+courses[0]['url'],timeout=30)
    response=s.get('http://127.0.0.1:8081/logout',timeout=30)
    form=next(f for f in Forms(response.text).forms if urllib.parse.urlparse(f['action']).path=='/logout')
    response=s.post(urllib.parse.urljoin(response.url,form['action']),data=form['fields'],timeout=30)
    check(username+' Canvas logout reaches central login',response.status_code==200 and urllib.parse.urlparse(response.url).netloc=='127.0.0.1:8082' and any('username' in f['fields'] for f in Forms(response.text).forms),{'status':response.status_code,'final_path':urllib.parse.urlparse(response.url).path})
    check(username+' Canvas logout revokes portal token',s.get(BASE+'/api/v1/me',headers={'Authorization':'Bearer '+fresh},timeout=20).status_code==401)
    check(username+' Canvas logout revokes Canvas cookie',s.get('http://127.0.0.1:8081/api/v1/users/self/profile',timeout=20).status_code==401)

  except Exception as error:
   check(username+' protocol completion',False,type(error).__name__)
  finally:
   if token:
    try:s.post(BASE+'/api/v1/identity/logout',json={},headers={'Authorization':'Bearer '+token,'Origin':BASE},timeout=10)
    except requests.RequestException:pass
   s.close()
result={'scope':'local HTTP OIDC/API protocol; loopback Secure-cookie exception emulated; not browser UI proof','passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'checks':checks}
(ROOT/'docs/tahap5a-hasil-uji-oidc-api.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'passed':result['passed'],'failed':result['failed']}))
raise SystemExit(1 if result['failed'] else 0)
