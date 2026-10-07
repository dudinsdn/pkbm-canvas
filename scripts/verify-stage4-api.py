#!/usr/bin/env python3
"""Requested Stage 4 local API verification. Temporary records removed by exact IDs."""
from pathlib import Path
import requests,json,uuid,subprocess,secrets
ROOT=Path(__file__).resolve().parents[1]
BASE='http://127.0.0.1:3000/api/v1'
ENV=dict(x.split('=',1) for x in (ROOT/'.env').read_text().splitlines() if '=' in x and not x.startswith('#'))
TABLES=['people','pkbm_memberships','role_assignments','program_offerings','learner_programs','learning_groups','group_memberships','learning_design_versions','design_components','learning_activities','activity_targets','deliveries','delivery_staff','delivery_enrollments','learning_plans','learning_plan_items','learning_sessions']
checks=[];created=[];clients={};snap={};run=uuid.uuid4().hex[:10]
def check(name,ok,detail=None):
 checks.append({'name':name,'passed':bool(ok),'detail':detail});print(name, 'PASS' if ok else 'FAIL',flush=True)
 if not ok:raise AssertionError(name)
def call(client,path,method='GET',data=None):return client.request(method,BASE+path,json=data,timeout=30)
def login(tenant,role,password=None,email=None):
 s=requests.Session();prefix={'pengelola':'ADMIN','tutor':'TUTOR','warga_belajar':'WB'}[role]
 r=call(s,'/session','POST',{'pkbm_code':tenant,'email':email or role+'@pkbm.local','password':password or ENV['PKBM_LOCAL_'+prefix+'_PASSWORD']})
 check('login_'+tenant+'_'+role,r.status_code==200)
 s.headers['Authorization']='Bearer '+r.json()['token'];m=call(s,'/me');check('identity_'+tenant+'_'+role,m.status_code==200 and role in m.json()['roles']);return s,m.json()
def records(client,table):
 r=call(client,'/operations/'+table);check('list_'+table,r.status_code==200);return r.json()['records']
def create(client,table,data):
 r=call(client,'/operations/'+table,'POST',{'record':data});check('create_'+table,r.status_code==201,{'status':r.status_code,'error':r.json().get('error') if r.status_code!=201 else None});row=r.json();created.append((table,row['id']));return row
try:
 anon=requests.Session()
 check('anonymous_denied',call(anon,'/me').status_code==401)
 check('invalid_login_denied',call(anon,'/session','POST',{'pkbm_code':'DEMO-A','email':'pengelola@pkbm.local','password':'incorrect'}).status_code==401)
 for tenant in ['DEMO-A','DEMO-B']:
  for role in ['pengelola','tutor','warga_belajar']:
   s,m=login(tenant,role);clients[(tenant,role)]=s
   for table in TABLES:
    rows=records(s,table);check('tenant_scope_'+tenant+'_'+role+'_'+table,all(x['pkbm_id']==m['pkbm_id'] for x in rows))
    check('password_not_serialized_'+tenant+'_'+role+'_'+table,all('password_digest' not in x for x in rows))
    if role=='pengelola':snap[(tenant,table)]=rows
   if role=='warga_belajar':
    check('wb_program_self_'+tenant,all(x['membership_id']==m['membership_id'] for x in records(s,'learner_programs')))
    check('wb_active_plans_only_'+tenant,all(x['status']=='active' for x in records(s,'learning_plans')))
 a=clients[('DEMO-A','pengelola')];b=clients[('DEMO-B','pengelola')];t=clients[('DEMO-A','tutor')];w=clients[('DEMO-A','warga_belajar')]
 check('tenants_distinct',call(a,'/me').json()['pkbm_id']!=call(b,'/me').json()['pkbm_id'])
 for role in ['pengelola','tutor','warga_belajar']:
  client=clients[('DEMO-A',role)]
  for table in TABLES:
   foreign=snap[('DEMO-B',table)][0]
   check('foreign_get_denied_'+role+'_'+table,call(client,'/operations/'+table+'/'+foreign['id']).status_code==404)
 for table in TABLES:
  check('wb_write_denied_'+table,call(w,'/operations/'+table,'POST',{'record':{'name':'Forbidden'}}).status_code==403)
 check('tutor_admin_write_denied',call(t,'/operations/role_assignments','POST',{'record':{'name':'Forbidden'}}).status_code==403)
 check('unknown_collection_denied',call(a,'/operations/schema_migrations').status_code==404)
 tampered=requests.Session();tampered.headers['Authorization']=a.headers['Authorization']+'altered'
 check('tampered_token_denied',call(tampered,'/me').status_code==401)
 spoof=requests.Session();spoof.headers.update(w.headers);spoof.headers.update({'X-PKBM-ID':call(b,'/me').json()['pkbm_id'],'X-Role':'pengelola'})
 check('forged_headers_denied',call(spoof,'/operations/people','POST',{'record':{'name':'Forbidden'}}).status_code==403)
 catalog={}
 for table in ['curriculum_versions','curriculum_levels','curriculum_components','learning_targets']:
  r=call(a,'/catalog/'+table+'?limit=100');check('catalog_'+table,r.status_code==200);catalog[table]=r.json()['records']
 prefix='API audit '+run
 password=secrets.token_hex(20)
 person=create(a,'people',{'name':prefix+' WB','email':run+'@audit.local','password':password,'pkbm_id':call(b,'/me').json()['pkbm_id'],'id':str(uuid.uuid4())})
 check('payload_tenant_ignored',person['pkbm_id']==call(a,'/me').json()['pkbm_id'])
 member=create(a,'pkbm_memberships',{'person_id':person['id']})
 create(a,'role_assignments',{'membership_id':member['id'],'role':'warga_belajar'})
 other,otherme=login('DEMO-A','warga_belajar',password,run+'@audit.local')
 version=catalog['curriculum_versions'][0]['id'];level=next(x for x in catalog['curriculum_levels'] if x['code']=='V')['id']
 program=create(a,'program_offerings',{'name':prefix,'curriculum_version_id':version,'period':'2026/2027','status':'active'})
 lp=create(a,'learner_programs',{'program_offering_id':program['id'],'membership_id':member['id'],'curriculum_level_id':level,'starts_on':'2026-10-07'})
 group=create(a,'learning_groups',{'program_offering_id':program['id'],'name':prefix,'period':'2026/2027'})
 create(a,'group_memberships',{'learning_group_id':group['id'],'learner_program_id':lp['id'],'starts_on':'2026-10-07'})
 tutor_member=call(t,'/me').json()['membership_id']
 design=create(t,'learning_design_versions',{'program_offering_id':program['id'],'owner_membership_id':member['id'],'name':prefix,'version':1,'kind':'mapel','local_adjustment':'Penyesuaian audit lokal'})
 check('tutor_owner_server_controlled',design['owner_membership_id']==tutor_member)
 check('empty_design_publish_denied',call(t,'/operations/learning_design_versions/'+design['id'],'PATCH',{'record':{'status':'published'}}).status_code==422)
 comp=next(x for x in catalog['curriculum_components'] if x['name'].startswith('Matematika') and x['specialization_track_id'] is None and x['catalog_key'].startswith('V:'))
 create(t,'design_components',{'learning_design_version_id':design['id'],'curriculum_component_id':comp['id']})
 activity=create(t,'learning_activities',{'learning_design_version_id':design['id'],'title':prefix,'position':1,'objective':'Menjelaskan penalaran','mode':'tutorial','evidence_plan':'Penjelasan tertulis','assessment_method':'Umpan balik tutor'})
 target=next(x for x in catalog['learning_targets'] if x['curriculum_component_id']==comp['id'] and x['kind']=='KD')
 foreign_target=next(x for x in catalog['learning_targets'] if x['curriculum_component_id']!=comp['id'])
 check('target_outside_design_denied',call(t,'/operations/activity_targets','POST',{'record':{'learning_activity_id':activity['id'],'learning_target_id':foreign_target['id'],'relation_type':'diajarkan'}}).status_code==422)
 create(t,'activity_targets',{'learning_activity_id':activity['id'],'learning_target_id':target['id'],'relation_type':'diajarkan'})
 r=call(t,'/operations/learning_design_versions/'+design['id'],'PATCH',{'record':{'status':'published'}});check('publish_complete_design',r.status_code==200)
 check('published_activity_immutable',call(t,'/operations/learning_activities/'+activity['id'],'PATCH',{'record':{'title':'Changed'}}).status_code==422)
 delivery=create(a,'deliveries',{'learning_design_version_id':design['id'],'learning_group_id':group['id'],'name':prefix,'period':'2026/2027','status':'active'})
 check('unassigned_tutor_delivery_hidden',call(t,'/operations/deliveries/'+delivery['id']).status_code==404)
 check('unassigned_tutor_session_denied',call(t,'/operations/learning_sessions','POST',{'record':{'delivery_id':delivery['id'],'learning_activity_id':activity['id'],'starts_at':'2026-10-12T08:00:00+07:00','mode':'tutorial','planned_jp':2}}).status_code==403)
 create(a,'delivery_staff',{'delivery_id':delivery['id'],'membership_id':tutor_member,'responsibility':'Pendamping uji'})
 check('assigned_tutor_delivery_visible',call(t,'/operations/deliveries/'+delivery['id']).status_code==200)
 create(a,'delivery_enrollments',{'delivery_id':delivery['id'],'learner_program_id':lp['id']})
 create(t,'learning_sessions',{'delivery_id':delivery['id'],'learning_activity_id':activity['id'],'starts_at':'2026-10-12T08:00:00+07:00','mode':'tutorial','planned_jp':2})
 plan=create(a,'learning_plans',{'learner_program_id':lp['id'],'version':1,'starts_on':'2026-10-07','objective':'Tujuan warga belajar audit','status':'active'})
 item=create(a,'learning_plan_items',{'learning_plan_id':plan['id'],'delivery_id':delivery['id'],'learning_target_id':target['id'],'position':1})
 check('other_wb_plan_denied',call(w,'/operations/learning_plans/'+plan['id']).status_code==404)
 check('other_wb_plan_item_denied',call(w,'/operations/learning_plan_items/'+item['id']).status_code==404)
 check('own_wb_plan_visible',call(other,'/operations/learning_plans/'+plan['id']).status_code==200)
 check('own_wb_item_visible',call(other,'/operations/learning_plan_items/'+item['id']).status_code==200)
 check('assigned_tutor_plan_visible',call(t,'/operations/learning_plans/'+plan['id']).status_code==200)
 second_delivery=create(a,'deliveries',{'learning_design_version_id':design['id'],'learning_group_id':group['id'],'name':prefix+' unassigned','period':'2026/2027','status':'active'})
 create(a,'delivery_enrollments',{'delivery_id':second_delivery['id'],'learner_program_id':lp['id']})
 second_item=create(a,'learning_plan_items',{'learning_plan_id':plan['id'],'delivery_id':second_delivery['id'],'learning_target_id':target['id'],'position':2})
 check('tutor_unassigned_plan_item_denied',call(t,'/operations/learning_plan_items/'+second_item['id']).status_code==404)
 check('wb_other_own_delivery_item_visible',call(other,'/operations/learning_plan_items/'+second_item['id']).status_code==200)

 check('second_active_plan_denied',call(a,'/operations/learning_plans','POST',{'record':{'learner_program_id':lp['id'],'version':2,'starts_on':'2026-10-07','objective':'Duplicate','status':'active'}}).status_code==422)
 check('foreign_fk_denied',call(a,'/operations/pkbm_memberships','POST',{'record':{'person_id':snap[('DEMO-B','people')][0]['id']}}).status_code in [404,422])
 check('foreign_patch_denied',call(a,'/operations/people/'+snap[('DEMO-B','people')][0]['id'],'PATCH',{'record':{'name':'Forbidden'}}).status_code==404)
 check('own_email_only',all('email' not in x or x['id']==person['id'] for x in records(other,'people')))
finally:
 # Exact temporary records only; PostgreSQL transaction ensures atomic cleanup.
 if created:
  statements=['BEGIN;']+[f"DELETE FROM {table} WHERE id='{id}';" for table,id in reversed(created)]+['COMMIT;']
  r=subprocess.run([str(ROOT/'scripts/compose'),'exec','-T','postgres','sh','-c','PGPASSWORD="$PKBM_DB_PASSWORD" exec psql -h 127.0.0.1 -U pkbm -d pkbm_development -v ON_ERROR_STOP=1 -q'],input='\n'.join(statements),text=True,capture_output=True)
  check('temporary_records_cleanup',r.returncode==0,{'records':len(created)})
 for tenant in ['DEMO-A','DEMO-B']:
  if (tenant,'pengelola') in clients:
   for table in TABLES:
    if (tenant,table) in snap:
     r=call(clients[(tenant,'pengelola')],'/operations/'+table)
     check('original_records_unchanged_'+tenant+'_'+table,r.status_code==200 and r.json()['records']==snap[(tenant,table)])
 out=ROOT/'var/validation/stage4';out.mkdir(parents=True,exist_ok=True)
 (out/'api-results.json').write_text(json.dumps({'checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks)},ensure_ascii=False,indent=2)+'\n')
