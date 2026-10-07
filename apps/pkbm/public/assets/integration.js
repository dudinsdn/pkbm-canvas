function IntegrationPanel({data,catalog,request}) {
  const E=React.createElement;
  const [state,setState]=React.useState(null),[error,setError]=React.useState(''),[notice,setNotice]=React.useState(''),[busy,setBusy]=React.useState(false);
  async function load(){try{setState(await request('integration'));setError('');}catch(e){setError(e.message);}}
  React.useEffect(()=>{load();},[]);
  async function change(path,method,body){setBusy(true);setNotice('');try{const result=await request(path,method,body);setNotice(result.execution||'Perubahan tersimpan.');await load();}catch(e){setError(e.message);}finally{setBusy(false);}}
  const deliveries=data.deliveries||[];
  const resources=catalog.learning_resources||[];
  return E('section',null,
    E('h2',null,'Hubungkan pembelajaran dengan Canvas'),
    E('p',null,'Program, peserta dan rancangan bersumber dari PKBM. Perubahan manual pada objek Canvas akan ditandai sebagai konflik untuk ditelaah.'),
    error&&E('p',{role:'alert',className:'error'},error),notice&&E('p',{role:'status',className:'success'},notice),
    E('section',{className:'card'},E('h3',null,state?.instance?.access_token_configured?'Otorisasi Canvas tersimpan':'Siapkan otorisasi Canvas'),
      E('p',null,'Gunakan token API Canvas lokal yang memiliki akses sub-account, Course, pengguna, enrollment, Outcomes, Pages dan external tools. Token tidak ditampilkan kembali.'),
      E('form',{onSubmit:async event=>{event.preventDefault();const form=event.target;const access_token=new FormData(form).get('access_token');await change('integration','PUT',{access_token});form.reset();}},
        E('label',null,'Token API Canvas',E('input',{name:'access_token',type:'password',required:true,maxLength:4096,autoComplete:'off'})),
        E('button',{disabled:busy},state?.instance?.access_token_configured?'Ganti token':'Simpan otorisasi'))),
    E('section',{className:'card'},E('h3',null,'Pilih bahan referensi'),
      E('p',null,'Bahan ditautkan sebagai referensi; temuan pemetaan tetap dicantumkan dan tidak menjadi klaim semua KD tercakup.'),
      E('form',{onSubmit:event=>{event.preventDefault();change('integration/resources','POST',Object.fromEntries(new FormData(event.target)));}},
        E('label',null,'Pelaksanaan',E('select',{name:'delivery_id',required:true},E('option',{value:''},'Pilih pelaksanaan'),deliveries.map(x=>E('option',{key:x.id,value:x.id},x.name)))),
        E('label',null,'Bahan',E('select',{name:'learning_resource_id',required:true},E('option',{value:''},'Pilih bahan'),resources.map(x=>E('option',{key:x.id,value:x.id},x.title)))),
        E('label',null,'Catatan penggunaan',E('textarea',{name:'note'})),E('button',{disabled:busy},'Simpan bahan'))),
    E('section',{className:'card'},E('h3',null,'Sinkronkan pelaksanaan'),
      E('form',{onSubmit:event=>{event.preventDefault();change('integration/jobs','POST',Object.fromEntries(new FormData(event.target)));}},
        E('label',null,'Pelaksanaan aktif',E('select',{name:'delivery_id',required:true},E('option',{value:''},'Pilih pelaksanaan'),deliveries.filter(x=>x.status==='active').map(x=>E('option',{key:x.id,value:x.id},x.name)))),
        E('button',{disabled:busy||!state?.instance},'Antrekan sinkronisasi')),
      E('p',{className:'muted'},'Antrean diproses ketika worker sinkronisasi dijalankan. Penyimpanan token saja tidak menguji koneksi atau memanggil Canvas.')),
    E('button',{type:'button',onClick:load},'Muat ulang status'),
    (state?.jobs||[]).map(job=>E('article',{key:job.id,className:'card'},
      E('h3',null,deliveries.find(x=>x.id===job.delivery_id)?.name||'Pelaksanaan'),E('p',null,'Status: '+job.status+' · Percobaan: '+job.attempts),
      job.last_error&&E('p',{className:'error'},job.last_error),
      ['failed','conflict'].includes(job.status)&&E('div',{className:'toolbar'},
        E('button',{disabled:busy,onClick:()=>change('integration/jobs/'+job.id+'/retry','POST',{force_local:false})},'Ulangi dengan pemeriksaan konflik'),
        job.status==='conflict'&&E('button',{disabled:busy,onClick:()=>{if(window.confirm('Terapkan rancangan PKBM pada objek terikat yang berubah di Canvas? Perubahan manual di Canvas dapat tertimpa.'))change('integration/jobs/'+job.id+'/retry','POST',{force_local:true});}},'Terapkan rancangan PKBM pada konflik')),
      E('details',null,E('summary',null,'Riwayat sinkronisasi'),(state.events||[]).filter(x=>x.sync_job_id===job.id).map(event=>E('p',{key:event.id},event.event_type+(event.object_kind?' · '+event.object_kind:'')))))));
}
function CanvasCourseLinks({request}) {
  const E=React.createElement;
  const [courses,setCourses]=React.useState([]),[error,setError]=React.useState('');
  React.useEffect(()=>{request('integration/links').then(x=>setCourses(x.courses)).catch(e=>setError(e.message));},[]);
  return E('section',{className:'card'},E('h2',null,'Pembelajaran di Canvas'),error&&E('p',{role:'alert'},error),courses.length?E('ul',null,courses.map(x=>E('li',{key:x.delivery_id},x.url?E('a',{href:x.url,target:'_blank',rel:'noopener noreferrer'},x.delivery_name||'Mulai belajar'):E('span',null,(x.delivery_name||'Pembelajaran')+' — akses sedang disiapkan oleh pengelola')))):E('p',null,'Pelaksanaan belum terhubung dengan Canvas. Pendamping dapat memberi informasi jadwal dan bahan.'));
}
function ResourceViewer({resourceId,deliveryId}) {
  const E=React.createElement;
  const [error,setError]=React.useState(''),[url,setUrl]=React.useState(null);
  React.useEffect(()=>{let cancelled=false;let blobUrl=null;
    fetch('/api/v1/integration/resources/'+encodeURIComponent(resourceId)+'?delivery_id='+encodeURIComponent(deliveryId),{headers:{Authorization:'Bearer '+sessionStorage.getItem('pkbm-token')}}).then(async response=>{if(!response.ok){const result=await response.json();throw Error(result.error||'Bahan tidak tersedia');}return response.blob();}).then(blob=>{blobUrl=URL.createObjectURL(blob);if(!cancelled)setUrl(blobUrl);else URL.revokeObjectURL(blobUrl);}).catch(e=>{if(!cancelled)setError(e.message);});
    return ()=>{cancelled=true;if(blobUrl)URL.revokeObjectURL(blobUrl);};
  },[resourceId,deliveryId]);
  return E('section',{className:'card'},E('h2',null,'Bahan referensi pembelajaran'),E('p',null,'Bahan ini merupakan sumber pembelajaran; bukan bukti ketuntasan atau pengesahan SKK.'),error?E('p',{className:'error',role:'alert'},error):url?E('a',{href:url,target:'_blank',rel:'noopener'},'Buka PDF sumber'):E('p',null,'Memuat bahan…'));
}
