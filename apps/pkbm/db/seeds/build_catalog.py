"""Generate source-backed catalog data; does not connect to PostgreSQL."""
from pathlib import Path
import json,uuid
ROOT=Path(__file__).resolve().parents[4]
SOURCE=ROOT/'docs/acuan/pemetaan-sumber-dan-aturan-pkbm.json'
data=json.loads(SOURCE.read_text())
NS=uuid.UUID('43d329bf-68b5-4a2b-b713-0e34600d556b')
tables={}
def uid(key): return str(uuid.uuid5(NS,key))
def add(table,key,**values):
 row=dict(id=uid(table+':'+key),catalog_key=key,**values)
 tables.setdefault(table,[]).append(row); return row['id']
def ref(source,pages,printed,section):
 key=f'{source}:{",".join(map(str,pages))}:{printed}:{section}'
 if key in refs:return refs[key]
 refs[key]=add('source_references',key,source_document_id=sources[source],pdf_page_start=min(pages),pdf_page_end=max(pages),printed_pages=printed,section=section)
 return refs[key]
sources={};refs={}
for s in data['sources']:
 sources[s['id']]=add('source_documents',s['id'],document_type=s['document_type'],title=s['title'],original_filename=Path(s['path']).name,path=s['path'],sha256=s['sha256'],pdf_pages=s['pdf_pages'],scope=s['scope'])
structure=ref('KUR-C',[6,7],'2–4','Struktur Paket C')
skillref=ref('PAN-KET',[7,8],'6–9','Keterampilan wajib dan pilihan')
cv=add('curriculum_versions','K13-C-user-sources-v1',name='Kurikulum Pendidikan Kesetaraan Paket C (sumber pengguna)',status='acuan_dokumen_pengguna',source_document_id=sources['KUR-C'])
tracks={k:add('specialization_tracks',k,curriculum_version_id=cv,code=k,name=v) for k,v in [('MIA','Matematika dan Ilmu Alam'),('IPS','Ilmu Pengetahuan Sosial'),('BB','Bahasa dan Budaya')]}
components={};levels={};frameworks={};targets={}
subjects=[('AGAMA','Pendidikan Agama dan Budi Pekerti'),('PPKN','Pendidikan Pancasila dan Kewarganegaraan'),('BID','Bahasa Indonesia'),('MTK','Matematika wajib'),('SEJIND','Sejarah Indonesia'),('BIG','Bahasa Inggris')]
choices={'MIA':[('MTK-MIN','Matematika peminatan'),('BIO','Biologi'),('FIS','Fisika'),('KIM','Kimia')],'IPS':[('GEO','Geografi'),('SEJ-MIN','Sejarah peminatan'),('SOS','Sosiologi'),('EKO','Ekonomi')],'BB':[('BID-SAS','Bahasa dan Sastra Indonesia'),('BIG-SAS','Bahasa dan Sastra Inggris'),('BA','Bahasa Asing lainnya'),('ANT','Antropologi')]}
for level,eq,budgets in [('V','Setara kelas X–XI',[26,30,24]),('VI','Setara kelas XII',[14,15,13])]:
 levels[level]=add('curriculum_levels',level,curriculum_version_id=cv,code=level,equivalence=eq)
 groups={k:add('curriculum_groups',level+':'+k,curriculum_level_id=levels[level],kind=k,name=n,skk_budget=b,source_reference_id=structure) for k,n,b in zip(['umum','peminatan','khusus'],['Umum','Peminatan','Khusus'],budgets)}
 def comp(code,name,group='umum',track=None,kind='mapel',subtype=None):
  key=level+':'+code
  components[key]=add('curriculum_components',key,curriculum_group_id=groups[group],specialization_track_id=tracks.get(track),kind=kind,name=name,local_code=code,subtype=subtype,source_reference_id=structure,coverage_status='struktur_saja',subject_skk=None)
  return components[key]
 for code,name in subjects:comp(code,name)
 for track,entries in choices.items():
  for code,name in entries:comp(code,name,'peminatan',track)
 comp('PEM','Pemberdayaan','khusus',kind='pemberdayaan')
 required=comp('KET-W','Keterampilan wajib','khusus',kind='keterampilan',subtype='wajib')
 elective=comp('KET-P','Keterampilan pilihan','khusus',kind='keterampilan',subtype='pilihan')
 for sc,sn in [('KET-PC','Keterampilan pilihan tersertifikasi'),('KET-PNS','Keterampilan pilihan nonsertifikasi')]:
  child=comp(sc,sn,'khusus',kind='keterampilan',subtype='pilihan_tersertifikasi' if sc=='KET-PC' else 'pilihan_nonsertifikasi')
  add('component_relations',level+':KET-P:'+sc,from_component_id=elective,to_component_id=child,relation_type='jenis_keterampilan_pilihan',source_reference_id=skillref)
 for code,name in [('SENI','Seni Budaya'),('OR','Pendidikan Olahraga dan Rekreasi'),('PRA','Prakarya')]:
  c=comp(code,name,'khusus',subtype='acuan_keterampilan_wajib')
  add('component_relations',level+':KET-W:'+code,from_component_id=required,to_component_id=c,relation_type='keterampilan_wajib_mengacu_mapel',source_reference_id=skillref)
for key,cid in components.items():
 level,code=key.split(':')
 src={'MTK':'SIL-MTK','BID':'SIL-BID','PEM':'PAN-PEM','KET-W':'PAN-KET','KET-P':'PAN-KET','KET-PC':'PAN-KET','KET-PNS':'PAN-KET'}.get(code)
 kind='silabus' if code in ['MTK','BID'] else 'panduan'
 if src:
  pages={'SIL-MTK':[11,12],'SIL-BID':[10],'PAN-PEM':[9,10,11,12,13,14,15],'PAN-KET':[7,8]}[src] if level=='V' else [1]
  rr=ref(src,pages,None,'Acuan tersedia; cakupan seed '+level)
 else:rr=None
 fk=add('academic_frameworks',key+':acuan',curriculum_component_id=cid,kind=kind if src else 'kurikulum',name='Acuan '+key,version=None,availability='tersedia_belum_lengkap' if src else 'silabus_belum_tersedia',source_reference_id=rr)
 frameworks[key]=fk

def target(compkey,key,kind,dim,text,rr,parent=None,source_code=None,display_code=None,typ='normalisasi_tipografi'):
 cid=components[compkey]
 tid=add('learning_targets',compkey+':'+key,curriculum_component_id=cid,kind=kind,dimension=dim,parent_id=parent,source_code=source_code,display_code=display_code,description=text,transcription_type=typ,source_reference_id=rr)
 targets[compkey+':'+key]=tid
 return tid
ki1='Menghayati dan mengamalkan ajaran agama yang dianutnya.'
ki2='Menunjukkan perilaku jujur, disiplin, tanggung jawab, peduli (gotong royong, kerjasama, toleran, damai), santun, responsif, dan proaktif sebagai bagian dari solusi atas berbagai permasalahan dalam berinteraksi secara efektif dengan lingkungan sosial dan alam serta menempatkan diri sebagai cerminan bangsa dalam pergaulan dunia.'
for code,page,printed in [('MTK',24,'38'),('BID',17,'24–25')]:
 ck='V:'+code;rr=ref('KUR-C',[23,24] if code=='MTK' else [17], '36–38' if code=='MTK' else printed,'KI/KD '+code+' Tingkatan V')
 for n,dim,txt in [('1','spiritual',ki1),('2','sosial',ki2),('3','pengetahuan','Memahami, menerapkan dan menganalisis pengetahuan untuk memecahkan masalah sesuai rumusan KI mata pelajaran.'),('4','keterampilan','Mengolah, menalar dan menyaji dalam ranah konkret dan abstrak sesuai rumusan KI mata pelajaran.')]:
  target(ck,'KI'+n,'KI',dim,txt,rr,source_code=n,display_code='KI '+n,typ='normalisasi_tipografi' if n in ['1','2'] else 'ringkasan_editorial')
mtk={
'3.1':'Menjelaskan makna dari persamaan dan pertidaksamaan nilai mutlak dari bentuk linear satu variabel dengan menggunakan contoh atau peristiwa kontekstual kemudian menjabarkannya ke dalam bentuk persamaan dan pertidaksamaan linear satu variabel lainnya.',
'4.1':'Menyelesaikan masalah kontekstual yang berkaitan dengan persamaan dan pertidaksamaan nilai mutlak linear satu variabel dengan menggunakan prosedur dan strategi penyelesaian masalah.',
'3.2':'Menjelaskan dan menentukan penyelesaian pertidaksamaan rasional dan irasional satu variabel dengan menggunakan sifat-sifat dan langkah-langkah penyelesaiannya.',
'4.2':'Menyelesaikan masalah kontekstual yang berkaitan dengan pertidaksamaan rasional dan irasional satu variabel dengan menggunakan prosedur dan strategi penyelesaian masalah.',
'3.3':'Menyatakan masalah kontekstual ke dalam model Matematika dengan bentuk sistem persamaan linear tiga variabel melalui identifikasi variabel-variabel dan besarannya.',
'4.3':'Menyelesaikan masalah kontekstual yang berkaitan dengan sistem persamaan linear tiga variabel dengan menggunakan prosedur dan strategi penyelesaian masalah.',
'3.4':'Menjelaskan dan menentukan penyelesaian sistem pertidaksamaan dua variabel (linear-kuadrat dan kuadrat-kuadrat) dengan menggunakan sifat-sifat dan langkah-langkah penyelesaiannya.',
'4.4':'Menyajikan masalah kontekstual dalam bentuk model Matematika yang berkaitan dengan sistem pertidaksamaan dua variabel (linear-kuadrat dan kuadrat-kuadrat) dan menyelesaikannya sesuai prosedur dan strategi penyelesaian masalah.'}
bid={
'3.1':'Mengidentifikasi laporan hasil observasi yang dipresentasikan dengan lisan dan tulis berkaitan dengan pekerjaan sesuai potensi daerah atau kehidupan sehari-hari.',
'4.1':'Menginterpretasi isi teks laporan hasil observasi baik secara lisan maupun tulis berkaitan pekerjaan sesuai dengan potensi daerah atau kehidupan sehari-hari.',
'3.2':'Menganalisis isi dan aspek kebahasaan dari minimal dua teks laporan hasil observasi tulis berkaitan kehidupan sehari-hari.',
'4.2':'Menyusun teks laporan dengan memerhatikan isi dan aspek kebahasaan baik lisan maupun tulis sesuai dengan kehidupan sehari-hari.'}
for code,values,page,printed,sil,sp in [('MTK',mtk,24,'38','SIL-MTK',[11,12]),('BID',bid,17,'25','SIL-BID',[10])]:
 ck='V:'+code;rr=ref('KUR-C',[page],printed,'KD '+code+' Tingkatan V')
 sr=ref(sil,sp,None,'Penjabaran KD/indikator '+code)
 for n,txt in values.items():
  tid=target(ck,n,'KD','pengetahuan' if n.startswith('3') else 'keterampilan',txt,rr,parent=targets[ck+':KI'+n[0]],source_code=n,display_code=n)
  add('framework_targets',ck+':'+n,academic_framework_id=frameworks[ck],learning_target_id=tid,curriculum_component_id=components[ck],relation_type='menjabarkan',source_reference_id=sr)
# Each row stores printed code and parent separately; repeated source codes are intentional.
ind={
'MTK':[
('3.1','3.1.1','Menemukan konsep sistem persamaan linear dari masalah kontekstual.'),('3.1','3.1.2','Menggunakan konsep sistem persamaan linear dalam penyelesaian soal.'),('3.1','3.1.3','Mengidentifikasi masalah yang berhubungan dengan sistem persamaan linear.'),
('4.1','4.1.1','Membuat model matematika dan menyelesaikannya dengan sistem persamaan linear.'),('4.1','4.1.2','Menyelesaikan masalah kontekstual yang berkaitan dengan sistem persamaan linear.'),('4.1','4.1.3','Mengidentifikasi masalah yang berhubungan dengan pertidaksamaan linear satu variabel.'),('4.1','4.1.4','Membuat model matematika dari masalah yang berkaitan dengan pertidaksamaan linear satu variabel.'),('4.1','4.1.5','Menyelesaikan model matematika yang berkaitan dengan pertidaksamaan linear satu variabel.'),
('3.2','3.2.1','Mengidentifikasi dan membedakan jenis pertidaksamaan linear, kuadrat, pecahan dan irasional.'),('3.2','3.2.2','Menentukan penyelesaian pertidaksamaan kuadrat.'),('3.2','3.2.3','Menentukan penyelesaian pertidaksamaan pecahan.'),('3.2','3.2.4','Menentukan penyelesaian pertidaksamaan irasional (bentuk akar).'),('4.2','4.2.1','Membuat model matematika dari masalah yang berkaitan dengan pertidaksamaan rasional dan irasional.'),('4.2','4.2.2','Menyelesaikan model matematika yang berkaitan dengan pertidaksamaan rasional dan irasional.'),
('3.3','3.3.1','Menemukan konsep sistem persamaan linear tiga variabel dari masalah kontekstual.'),('3.3','3.3.2','Menggunakan konsep sistem persamaan linear tiga variabel dalam penyelesaian soal.'),('4.3','4.3.1','Mengidentifikasi masalah kontekstual yang berhubungan dengan sistem persamaan linear tiga variabel.'),('4.3','4.3.2','Membuat model matematika dan menyelesaikannya dengan sistem persamaan linear tiga variabel.'),
('3.4','3.2.2','Menentukan penyelesaian sistem pertidaksamaan dua variabel (linear-kuadrat).'),('3.4','3.2.3','Menentukan penyelesaian sistem pertidaksamaan dua variabel (kuadrat-kuadrat).'),('4.4','4.2.1','Membuat model matematika dari masalah yang berkaitan dengan pertidaksamaan dua variabel (linear-kuadrat dan kuadrat-kuadrat).'),('4.4','4.2.2','Menyelesaikan model matematika yang berkaitan dengan pertidaksamaan dua variabel (linear-kuadrat dan kuadrat-kuadrat).')],
'BID':[
('3.1','3.1.1','Menentukan isi pokok teks laporan hasil observasi.'),('3.1','3.1.2','Menanggapi laporan hasil observasi yang dipresentasikan dengan lisan dan tulis sesuai konteks pekerjaan atau kehidupan sehari-hari.'),('4.1','4.1.1','Mengidentifikasi kata atau kalimat yang memiliki makna khusus dalam teks laporan hasil observasi.'),('4.1','4..1.2','Menginterpretasi isi teks laporan hasil observasi berkaitan dengan pekerjaan atau kehidupan sehari-hari secara lisan atau tulis.'),('3.2','3.2.1','Mengidentifikasi isi (struktur) teks laporan hasil observasi.'),('3.2','3.2.2','Mengidentifikasi aspek kebahasaan dalam teks laporan hasil observasi.'),('4.2','4.2.1','Menyusun kerangka teks laporan hasil observasi.'),('4.2','4.2.2','Menulis teks laporan hasil observasi berdasarkan kerangka dengan memerhatikan isi dan aspek kebahasaan.'),('4.2','4.2.3','Menyunting teks laporan hasil observasi dengan memerhatikan isi dan aspek kebahasaan.')]
}
for code,rows in ind.items():
 ck='V:'+code
 for parent,printed,txt in rows:
  pages=([12] if parent in ['3.3','4.3','3.4','4.4'] else [11]) if code=='MTK' else [10]
  rr=ref('SIL-'+code,pages,None,'Indikator KD '+parent)
  tid=target(ck,parent+':'+printed,'indikator','pengetahuan' if parent.startswith('3') else 'keterampilan',txt,rr,parent=targets[ck+':'+parent],source_code=printed,display_code=printed.replace('..','.'),typ='ringkasan_editorial')
  add('framework_targets',ck+':indikator:'+parent+':'+printed,academic_framework_id=frameworks[ck],learning_target_id=tid,curriculum_component_id=components[ck],relation_type='menjabarkan',source_reference_id=rr)
for level in ['V','VI']:
 ck=level+':PEM';rr=ref('PAN-PEM',[15],'23','Tabel 5 Paket C; pengetahuan, keterampilan dan sikap')
 area_ref=ref('PAN-PEM',[16],'24–25','Area pemberdayaan; ringkasan panduan')
 for n,txt in enumerate(['Kemandirian diri dan kolektif untuk memecahkan masalah sosial-ekonomi.','Kemandirian diri dan kolektif untuk apresiasi.','Kemandirian diri dan kolektif untuk kreativitas dan inovasi.'],1):
  target(ck,'area-'+str(n),'area_panduan','lintas_dimensi',txt,area_ref,typ='ringkasan_editorial')
 for dim,entries in [('pengetahuan',['Potensi diri dan kelompok.','Keragaman dan kemanfaatan alam sekitar.','Keragaman, kemanfaatan dan nilai sosial.','Keragaman, keindahan dan nilai budaya sekitar.','Keragaman dan kemanfaatan ruang publik.']),('keterampilan',['Membangun jiwa mandiri dan kerja kolektif.','Mengidentifikasi karya budaya untuk menyuarakan kepentingan bersama.']),('sikap',['Menjadi representasi kelompok memanfaatkan ruang publik untuk kepentingan diri dan kelompok.','Memanfaatkan teknologi untuk unjuk karya di ruang publik.'])]:
  for n,txt in enumerate(entries,1):
   tid=target(ck,dim+'-'+str(n),'capaian_panduan',dim,txt,rr,typ='ringkasan_editorial')
   add('framework_targets',ck+':'+dim+str(n),academic_framework_id=frameworks[ck],learning_target_id=tid,curriculum_component_id=components[ck],relation_type='merujuk',source_reference_id=rr)
for ck,entries,src,pages in [('V:MTK',[('Persamaan dan pertidaksamaan nilai mutlak','Membaca bahan, memodelkan masalah kontekstual dan menyelesaikan persamaan/pertidaksamaan.',['3.1','4.1']),('Pertidaksamaan rasional dan irasional','Mengidentifikasi bentuk pertidaksamaan dan menyelesaikan masalah kontekstual.',['3.2','4.2']),('Sistem persamaan linear tiga variabel','Mengidentifikasi variabel, membuat model dan menafsirkan penyelesaian.',['3.3','4.3']),('Sistem pertidaksamaan dua variabel','Memodelkan dan menyelesaikan pertidaksamaan linear-kuadrat dan kuadrat-kuadrat.',['3.4','4.4'])],'SIL-MTK',[11,12]),('V:BID',[('Isi laporan hasil observasi','Membaca atau mendengarkan laporan, menentukan isi pokok dan menginterpretasi isi.',['3.1','4.1']),('Struktur dan kebahasaan laporan hasil observasi','Menganalisis teks, menyusun kerangka, menulis dan menyunting laporan.',['3.2','4.2'])],'SIL-BID',[10])]:
 rr=ref(src,pages,None,'Materi dan kegiatan; ringkasan editorial')
 for n,(title,desc,codes) in enumerate(entries,1):
  add('framework_topics',ck+':'+str(n),academic_framework_id=frameworks[ck],title=title,description='Ringkasan materi sumber; bukan salinan verbatim.',position=n,source_reference_id=rr)
  aid=add('framework_activities',ck+':'+str(n),academic_framework_id=frameworks[ck],description=desc,position=n,source_reference_id=rr)
  for code in codes:add('framework_activity_targets',ck+':'+str(n)+':'+code,framework_activity_id=aid,learning_target_id=targets[ck+':'+code])
findings={}
for key,src,pages,kind,txt,interpret in [
('MAP-04','MOD-MTK-V-01',[20,21],'perbedaan_konsep','Bagian dua variabel berisi persamaan, sedangkan KD 3.4/4.4 memerlukan pertidaksamaan.','Tidak menjadi klaim otomatis memenuhi KD 3.4/4.4.'),
('SIL-MTK-REPEATED','SIL-MTK',[12],'kode_sumber','Kode indikator tercetak berulang di bawah KD 3.4/4.4.','Pertahankan kode sumber; UUID dan parent membedakan indikator.'),
('SIL-BID-TYPO','SIL-BID',[10],'typo','Kode indikator tercetak 4..1.2.','Kode sumber dipertahankan; tampilan dinormalisasi menjadi 4.1.2.')]:
 rr=ref(src,pages,None,'Temuan pemetaan')
 findings[key]=add('source_findings',key,source_reference_id=rr,kind=kind,finding=txt,working_interpretation=interpret,status='tercatat',provenance=[])
resources={}
for src in ['MOD-MTK-V-01','MOD-MTK-V-02','MOD-BID-V-01']:
 s=next(x for x in data['sources'] if x['id']==src)
 resources[src]=add('learning_resources',src,kind='modul_PDF',title=s['title'],source_document_id=sources[src],version=None)
 ck='V:BID' if 'BID' in src else 'V:MTK'
 add('resource_components',src+':'+ck,learning_resource_id=resources[src],curriculum_component_id=components[ck])
for m in data['module_mappings']:
 p=m['provenance'][0]; rr=ref(p['source_id'],p['pdf_pages'],p.get('printed_pages'),p['section'])
 rid=resources[m['module_id']]
 un=add('resource_units',m['id'],learning_resource_id=rid,title=m['unit'],source_reference_id=rr)
 ck='V:BID' if 'BID' in m['module_id'] else 'V:MTK'
 for code in m['kd_codes']:
  add('resource_target_mappings',m['id']+':'+code,learning_resource_id=rid,resource_unit_id=un,learning_target_id=targets[ck+':'+code],relationship='landasan' if 'landasan' in m['status'] else 'cakupan_bahan',status=m['status'],rationale=m['coverage']+' '+m.get('note',''),source_reference_id=rr,source_finding_id=findings.get(m['id']),provenance=m['provenance'],proves_learner_mastery=False)
for rule in data['rules']:
 add('source_policy_statements',rule['id'],basis=rule['basis'],scope=rule['scope'],statement=rule['statement'],implementation_note=rule['implementation'],unresolved=rule['unresolved'],provenance=rule['provenance'],executable=False)
for row in tables['curriculum_components']:
 if row['catalog_key'] in ['V:MTK','V:BID']: row['coverage_status']='KI_ringkasan_KD_contoh_indikator_sebagian'
 elif row['local_code']=='PEM':row['coverage_status']='area_dan_capaian_Paket_C_sebagian'
output={'schema_version':1,'source_mapping_version':data['schema_version'],'scope':'Katalog bersama; bukan data PKBM atau pengesahan capaian','tables':tables}
(Path(__file__).parent/'catalog.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
print('Catalog seed generated; no database connection.')
