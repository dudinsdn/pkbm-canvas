class CanvasAssessmentPublisher
  def initialize(sync, api, job)
    @sync, @api, @job = sync, api, job
  end
  def publish(delivery, cid)
    plans = AssessmentPlan.where(pkbm_id: @job.pkbm_id, delivery_id: delivery.id, status: 'published').order(:version).to_a.group_by(&:learning_resource_id).values.map(&:last)
    plans.each do |plan|
      AssessmentRules.validate!(plan.blueprint)
      bp=plan.blueprint
      mod=object('assessment_module',plan.id,{'name'=>"#{bp.fetch('title')} · v#{plan.version}",'published'=>true},cid,'modules','module',%w[name published])
      Array(bp['units']).each_with_index do |unit,index|
        marker="pkbm-assessment:#{plan.id}:unit:#{unit.fetch('key')}"
        body="<p>#{esc(unit.fetch('instructions'))}</p><p>Acuan: #{esc(unit['source'])}</p><p>#{esc(unit['finding'])}</p><p><a href=\"#{ENV.fetch('PKBM_PUBLIC_BASE_URL')}/#resource=#{plan.learning_resource_id}&amp;delivery=#{delivery.id}\">Buka PDF sumber</a></p><p>#{esc(marker)}</p>"
        desired={'title'=>unit.fetch('title'),'body'=>body,'published'=>true,'editing_roles'=>'teachers'}
        page=@sync.ensure_object('assessment_page',marker,desired,context:cid,
          lookup: -> { unique(@api.list("/api/v1/courses/#{cid}/pages").filter_map { |x| p=@api.request('GET',"/api/v1/courses/#{cid}/pages/#{x.fetch('url')}");p if p['body'].to_s.include?(marker) }) },
          create: ->(p) { @api.request('POST',"/api/v1/courses/#{cid}/pages",{'wiki_page'=>p}) },
          get: ->(id) { @api.request('GET',"/api/v1/courses/#{cid}/pages/#{id}",nil,allow_missing:true) },
          update: ->(id,p) { @api.request('PUT',"/api/v1/courses/#{cid}/pages/#{id}",{'wiki_page'=>p}) }, fields:%w[title body published],id_field:'url')
        module_item(cid,mod['id'],marker,{'type'=>'Page','page_url'=>page['url'],'position'=>index+1})
      end
      bp.fetch('items').each_with_index do |item,index|
        key="#{plan.id}:#{item.fetch('key')}"; marker="pkbm-assessment:#{key}"
        description="<p>#{esc(item.fetch('instructions'))}</p><p>Asal instrumen: #{esc(item.fetch('basis'))}. #{esc(item['source'])}</p><p>#{esc(item['finding'])}</p><p>#{esc(marker)}</p><p>Umpan balik dan revisi merupakan bagian belajar; hasil tidak otomatis mengesahkan SKK.</p>"
        if item['kind']=='tam'
          desired={'title'=>item.fetch('title'),'description'=>description,'quiz_type'=>'assignment','allowed_attempts'=>1,'scoring_policy'=>'keep_latest','hide_results'=>'until_after_last_attempt','show_correct_answers'=>false,'published'=>false,'only_visible_to_overrides'=>true}
          quiz=object('quiz',key,desired,cid,'quizzes','quiz',%w[title description quiz_type allowed_attempts only_visible_to_overrides],marker:marker,title:'title')
          item.fetch('questions').each_with_index do |q,qi|
            qkey="#{key}:#{qi}"; qname="PKBM #{plan.id[0,8]} #{item['key']} #{qi+1}"
            payload={'question_name'=>qname,'question_type'=>'multiple_choice_question','question_text'=>"<p>#{esc(q.fetch('text'))}</p>",'points_possible'=>1,'position'=>qi+1,'answers'=>q.fetch('answers').each_with_index.map { |answer,ai| {'text'=>answer,'weight'=>ai==q.fetch('correct') ? 100 : 0} }}
            path="/api/v1/courses/#{cid}/quizzes/#{quiz['id']}/questions"
            @sync.ensure_object('quiz_question',qkey,payload,context:"#{cid}:#{quiz['id']}",lookup: -> { unique(@api.list(path).select { |x| x['question_name']==qname }) },create: ->(p) {@api.request('POST',path,{'question'=>p})},get: ->(id) {@api.request('GET',"#{path}/#{id}",nil,allow_missing:true)},update: ->(id,p) {@api.request('PUT',"#{path}/#{id}",{'question'=>p})},fields:%w[question_name question_text question_type points_possible])
          end
          @api.request('PUT',"/api/v1/courses/#{cid}/assignments/#{quiz.fetch('assignment_id')}",{'assignment'=>{'omit_from_final_grade'=>true,'only_visible_to_overrides'=>!!bp.dig('policy','prerequisite_resource_id') || (Array(item['mapping_keys']) & %w[MAP-09 MAP-10]).any?}})
          # A formal test is released deliberately by the assigned tutor, never by sync.
          module_item(cid,mod['id'],key,{'type'=>'Quiz','content_id'=>quiz['id'],'position'=>bp['units'].length+index+1})
        else
          maximum=item.fetch('rubric').sum { |x| x.fetch('points') }
          desired={'name'=>item.fetch('title'),'description'=>description,'submission_types'=>['online_text_entry','online_url','online_upload'],'points_possible'=>maximum,'grading_type'=>'points','published'=>true,'omit_from_final_grade'=>true,'only_visible_to_overrides'=>!!bp.dig('policy','prerequisite_resource_id') || (Array(item['mapping_keys']) & %w[MAP-09 MAP-10]).any?}
          assignment=object('assignment',key,desired,cid,'assignments','assignment',%w[name description points_possible submission_types published omit_from_final_grade only_visible_to_overrides],marker:marker)
          criteria=item.fetch('rubric').each_with_index.to_h { |criterion,i| [i.to_s,{'id'=>criterion.fetch('key'),'description'=>criterion.fetch('description'),'points'=>criterion.fetch('points'),'criterion_use_range'=>true,'ratings'=>{'0'=>{'description'=>'Belum ditunjukkan','points'=>0},'1'=>{'description'=>'Bukti lengkap sesuai kriteria','points'=>criterion['points']}}}] }
          rubric={'title'=>"#{item['title']} · #{plan.id[0,8]}",'free_form_criterion_comments'=>true,'criteria'=>criteria}
          @sync.ensure_object('rubric',key,rubric,context:cid,
            lookup: -> { full=@api.request('GET',"/api/v1/courses/#{cid}/assignments/#{assignment['id']}"); id=full.dig('rubric_settings','id');id && @api.request('GET',"/api/v1/courses/#{cid}/rubrics/#{id}") },
            create: ->(p) { result=@api.request('POST',"/api/v1/courses/#{cid}/rubrics",{'rubric'=>p,'rubric_association'=>{'association_id'=>assignment['id'],'association_type'=>'Assignment','use_for_grading'=>true,'purpose'=>'grading'}});result.fetch('rubric') },
            get: ->(id) { @api.request('GET',"/api/v1/courses/#{cid}/rubrics/#{id}",nil,allow_missing:true) },
            update: ->(id,_p) { @api.request('GET',"/api/v1/courses/#{cid}/rubrics/#{id}") },fields:%w[title points_possible data])
          module_item(cid,mod['id'],key,{'type'=>'Assignment','content_id'=>assignment['id'],'position'=>bp['units'].length+index+1})
        end
      end
      @sync.event('assessment_published','assessment_module',plan.id,{'version'=>plan.version,'recap'=>'per_attempt_no_aggregate','tam_released'=>false})
    end
  end
  private
  def esc(value)=CGI.escapeHTML(value.to_s)
  def unique(rows)
    raise CanvasSync::Conflict,'Instrumen Canvas memiliki beberapa kandidat' if rows.length>1
    rows.first
  end
  def object(kind,key,desired,cid,collection,wrapper,fields,marker:nil,title:'name')
    path="/api/v1/courses/#{cid}/#{collection}"
    @sync.ensure_object(kind,key,desired,context:cid,
      lookup: -> { unique(@api.list(path).select { |x| marker ? x['description'].to_s.include?(marker) : x[title]==desired[title] }) },
      create: ->(p) {@api.request('POST',path,{wrapper=>p})},get: ->(id) {@api.request('GET',"#{path}/#{id}",nil,allow_missing:true)},update: ->(id,p) {@api.request('PUT',"#{path}/#{id}",{wrapper=>p})},fields:fields)
  end
  def module_item(cid,mid,key,desired)
    path="/api/v1/courses/#{cid}/modules/#{mid}/items"
    @sync.ensure_object('assessment_item',key,desired,context:"#{cid}:#{mid}",lookup: -> { unique(@api.list(path).select { |x| x['type']==desired['type'] && (desired['page_url'] ? x['page_url']==desired['page_url'] : x['content_id'].to_s==desired['content_id'].to_s) }) },create: ->(p) {@api.request('POST',path,{'module_item'=>p})},get: ->(id) {@api.request('GET',"#{path}/#{id}",nil,allow_missing:true)},update: ->(id,p) {@api.request('PUT',"#{path}/#{id}",{'module_item'=>p})},fields:%w[type content_id page_url position])
  end
end
