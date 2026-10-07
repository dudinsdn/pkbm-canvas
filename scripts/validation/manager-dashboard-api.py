import pathlib,requests,json,urllib.parse,html.parser
root=pathlib.Path(__file__).resolve().parents[2]
env=dict(x.split('=',1) for x in (root/'.env').read_text().splitlines() if '=' in x and not x.startswith('#'))
class Forms(html.parser.HTMLParser):
 def __init__(self,text):super().__init__();self.forms=[];self.form=None;self.feed(text)
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='form':self.form={'action':a.get('action',''),'fields':{}};self.forms.append(self.form)
  if tag=='input' and self.form is not None and a.get('name'):self.form['fields'][a['name']]=a.get('value','')
 def handle_endtag(self,tag):
  if tag=='form':self.form=None
class Session(requests.Session):
 def prepare_request(self,r):
  if urllib.parse.urlparse(r.url).hostname=='127.0.0.1':
   for c in self.cookies:
    if c.domain=='127.0.0.1':c.secure=False
  return super().prepare_request(r)
checks=[]
def check(name,ok,detail=None):checks.append(dict(name=name,passed=bool(ok),detail=detail));print(name,'PASS' if ok else 'FAIL',detail or '',flush=True)
base='http://127.0.0.1:3000';canvas='http://127.0.0.1:8081'
for tenant,account,user,other in [('demo-a','4',9,'5'),('demo-b','5',10,'4')]:
 s=Session();s.headers['Accept']='text/html';token=None
 try:
  r=s.get(base+'/auth/login',timeout=40);f=next(f for f in Forms(r.text).forms if 'username' in f['fields'])
  r=s.post(urllib.parse.urljoin(r.url,f['action']),data=f['fields']|dict(username=tenant+'-pengelola',password=env['PKBM_LOCAL_ADMIN_PASSWORD']),timeout=40)
  r=s.get(base+'/api/v1/identity/contexts',timeout=30);check(tenant+' portal login',r.status_code==200)
  ctx=r.json()['contexts'][0];r=s.post(base+'/api/v1/identity/context',json=ctx,headers={'Origin':base},timeout=30);token=r.json()['token'];headers={'Authorization':'Bearer '+token}
  r=s.get(base+'/api/v1/integration/links',headers=headers,timeout=30);check(tenant+' management link',r.status_code==200 and r.json().get('management',{}).get('url')=='/kelola/canvas')
  r=s.get(base+'/kelola/canvas',timeout=50);check(tenant+' manager landing',r.status_code==200 and urllib.parse.urlparse(r.url).path=='/accounts/'+account and 'Kelola pembelajaran' in r.text,{'status':r.status_code,'path':urllib.parse.urlparse(r.url).path})
  r=s.get(canvas+'/api/v1/users/self/profile',timeout=30);check(tenant+' correct Canvas identity',r.status_code==200 and r.json().get('id')==user)
  r=s.get(canvas+'/',timeout=40);check(tenant+' Dashboard redirects to PKBM',r.status_code==200 and urllib.parse.urlparse(r.url).path=='/accounts/'+account and 'pkbm-manager-title' in r.text,{'status':r.status_code,'path':urllib.parse.urlparse(r.url).path})
  check(tenant+' portal return link', 'href="http://127.0.0.1:3000/"' in r.text)
  wildcard=s.get(canvas+'/',headers={'Accept':'*/*'},timeout=40)
  check(tenant+' wildcard dashboard HTML',wildcard.status_code==200 and urllib.parse.urlparse(wildcard.url).path=='/accounts/'+account and 'pkbm-manager-title' in wildcard.text)
  account_json=s.get(canvas+'/api/v1/accounts/'+account,headers={'Accept':'*/*'},timeout=30)
  check(tenant+' account API stays JSON',account_json.status_code==200 and account_json.headers.get('Content-Type','').startswith('application/json') and str(account_json.json().get('id'))==account)

  for path in ['/accounts/'+account+'/search','/accounts/'+account+'/users','/accounts/'+account+'/settings','/pkbm-manager.css']:
   nav=s.get(canvas+path,timeout=40);check(tenant+' navigation '+path,nav.status_code==200,nav.status_code)
  for target in [account,other,'1']:
   r=s.get(canvas+'/api/v1/accounts/'+target+'/courses',timeout=30);check(tenant+' courses scope '+target,r.status_code==200 if target==account else r.status_code in [401,403,404],r.status_code)
 except Exception as e:check(tenant+' completion',False,type(e).__name__)
 finally:
  try:
   r=s.post(base+'/api/v1/identity/logout',json={},headers={'Origin':base,**({'Authorization':'Bearer '+token} if token else {})},timeout=30)
   if r.status_code==200:s.get(r.json()['logout_url'],timeout=40)
  except requests.RequestException:pass
result={'scope':'Local HTTP/API manager dashboard; loopback cookie exception emulated; no rendered browser proof','passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'checks':checks}
(root/'docs/tahap5a-hasil-uji-dashboard-pengelola.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k] for k in ['passed','failed']}))
raise SystemExit(bool(result['failed']))
