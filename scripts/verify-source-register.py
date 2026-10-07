#!/usr/bin/env python3
"""Source identity/reference integrity checks; semantic review is documented separately."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
M=json.loads((ROOT/'docs/acuan/pemetaan-sumber-dan-aturan-pkbm.json').read_text())
D=json.loads((ROOT/'apps/pkbm/db/seeds/catalog.json').read_text())['tables']
checks=[]
def ck(name,ok,detail=None):
 checks.append({'check':name,'passed':bool(ok),'detail':detail})
 if not ok:raise AssertionError(name)
try:
 sources={s['id']:s for s in M['sources']}
 for source in M['sources']:
  p=Path(source['path']);h=hashlib.sha256(p.read_bytes()).hexdigest()
  info=subprocess.check_output(['pdfinfo',str(p)],text=True)
  pages=int(re.search(r'^Pages:\s+(\d+)',info,re.M).group(1))
  ck('identity_'+source['id'],h==source['sha256'] and pages==source['pdf_pages'],{'sha256':h,'pdf_pages':pages})
  row=next(r for r in D['source_documents'] if r['catalog_key']==source['id'])
  ck('registry_'+source['id'],row['sha256']==h and row['pdf_pages']==pages and row['path']==str(p))
 doc={d['id']:d for d in D['source_documents']}
 refs={r['id']:r for r in D['source_references']}
 for ref in refs.values():
  source=doc[ref['source_document_id']]
  ck('reference_bounds_'+ref['catalog_key'],1<=ref['pdf_page_start']<=ref['pdf_page_end']<=source['pdf_pages'])
 for kind,rows in [('mapping',M['module_mappings']),('rule',M['rules'])]:
  for row in rows:
   for prov in row['provenance']:
    src=sources[prov['source_id']]
    ck(kind+'_'+row['id']+'_'+src['id'],all(1<=p<=src['pdf_pages'] for p in prov['pdf_pages']))
   if kind=='rule':ck('rule_basis_'+row['id'],bool(row['provenance']) if row['basis']=='eksplisit_sumber' else row['basis']=='keputusan_desain')
 comp={r['id']:r for r in D['curriculum_components']};target={r['id']:r for r in D['learning_targets']}
 for row in target.values():
  ck('target_parent_context_'+row['catalog_key'],not row['parent_id'] or target[row['parent_id']]['curriculum_component_id']==row['curriculum_component_id'])
  ck('target_transcription_'+row['catalog_key'],row['transcription_type'] in ['normalisasi_tipografi','ringkasan_editorial','kutipan'])
 for mapping in M['module_mappings']:
  rows=[r for r in D['resource_target_mappings'] if r['catalog_key'].startswith(mapping['id']+':')]
  ck('mapping_kd_'+mapping['id'],{target[r['learning_target_id']]['source_code'] for r in rows}==set(mapping['kd_codes']) and all(r['status']==mapping['status'] and not r['proves_learner_mastery'] for r in rows))
 keys={r['catalog_key'] for r in D['curriculum_components']}
 codes={'AGAMA','PPKN','BID','MTK','SEJIND','BIG','MTK-MIN','BIO','FIS','KIM','GEO','SEJ-MIN','SOS','EKO','BID-SAS','BIG-SAS','BA','ANT','PEM','KET-W','KET-P','KET-PC','KET-PNS','SENI','OR','PRA'}
 ck('component_inventory_52',keys=={level+':'+code for level in ['V','VI'] for code in codes})
 ck('module_count_3',len(D['learning_resources'])==3)
 ck('guides_are_not_modules',{row['source_document_id'] for row in D['learning_resources']}.isdisjoint({r['id'] for r in D['source_documents'] if r['document_type']=='panduan_penyelenggaraan'}))
 ck('no_automatic_skk_or_mastery',all(r['subject_skk'] is None for r in D['curriculum_components']) and all(not r['proves_learner_mastery'] for r in D['resource_target_mappings']) and all(not r['executable'] for r in D['source_policy_statements']))
 ck('normalization_typo_preserved',any(r['source_code']=='4..1.2' and r['display_code']=='4.1.2' for r in target.values()))
 # Local document links only; external references are historical source links, not availability checks.
 local_links=[]
 for p in list((ROOT/'docs').rglob('*.md'))+[ROOT/'README.md',ROOT/'apps/pkbm/README.md']:
  for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
   link=link.strip('<>').split('#')[0]
   if not link or '://' in link or link.startswith('mailto:'):continue
   resolved=Path(link) if link.startswith('/') else p.parent/link
   ck('local_link_'+str(p.relative_to(ROOT))+':'+link,resolved.exists())
 print('Source/register integrity checks:',len(checks),'PASS')
finally:
 out=ROOT/'var/validation/stage12/source-register-results.json';out.parent.mkdir(parents=True,exist_ok=True)
 out.write_text(json.dumps({'scope':'identity, page bounds, catalog references and inventories; semantic comparison in docs/tahap12-verifikasi.md','checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks)},ensure_ascii=False,indent=2)+'\n')
