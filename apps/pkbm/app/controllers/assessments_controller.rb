class AssessmentsController < OperationsController
  rescue_from KeyError, TypeError do
    render json:{error:'Struktur instrumen belum lengkap atau tidak sesuai'},status: :unprocessable_entity
  end
  rescue_from CanvasApi::Error do |error|
    render json:{error:error.message},status: :bad_gateway
  end
  def index
    ids=@scope.records('deliveries').pluck(:id)
    plans=AssessmentPlan.where(pkbm_id:@scope.pkbm_id,delivery_id:ids).order(:version)
    plans=plans.where(status:'published') unless @scope.manager? || @scope.tutor?
    render json:{plans:plans.map { |p| serialize_plan(p) },attempts:attempts.where(assessment_plan_id:plans.select(:id)).order(:captured_at).limit(500),actions:actions.where(assessment_plan_id:plans.select(:id)).order(:created_at).limit(500),academic_decisions_enabled:false}
  end
  def update
    plan=plan!;staff!(plan)
    raise OperationWriter::Invalid,'Versi terbit dipertahankan; buat versi baru' unless plan.status=='draft'
    bp=params.require(:blueprint).permit!.to_h
    validate_targets!(plan,bp)
    plan.update!(blueprint:bp)
    render json:serialize_plan(plan)
  end
  def publish
    plan=plan!;staff!(plan)
    raise OperationWriter::Invalid,'Telaah instrumen dan kebijakan lokal wajib dikonfirmasi' unless params[:review_acknowledged]==true
    plan.with_lock do
      raise OperationWriter::Invalid,'Versi sudah terbit' unless plan.status=='draft'
      AssessmentRules.validate!(plan.blueprint);validate_targets!(plan,plan.blueprint)
      plan.update!(status:'published',reviewed_by:@scope.membership_id,reviewed_at:Time.current)
      DeliveryResource.find_or_create_by!(pkbm_id:@scope.pkbm_id,delivery_id:plan.delivery_id,learning_resource_id:plan.learning_resource_id) { |r|r.id=SecureRandom.uuid;r.note='Bahan pelaksanaan yang ditelaah tutor; temuan sumber tetap berlaku' }
    end
    render json:{plan:serialize_plan(plan),execution:'Versi ditelaah; antrekan sinkronisasi untuk membuat instrumen Canvas'}
  end
  def clone_version
    plan=plan!;staff!(plan)
    row=nil
    plan.with_lock do
      version=AssessmentPlan.where(pkbm_id:@scope.pkbm_id,delivery_id:plan.delivery_id,learning_resource_id:plan.learning_resource_id).maximum(:version).to_i+1
      row=AssessmentPlan.create!(id:SecureRandom.uuid,pkbm_id:@scope.pkbm_id,delivery_id:plan.delivery_id,learning_resource_id:plan.learning_resource_id,version:version,blueprint:plan.blueprint.deep_dup)
    end
    render json:serialize_plan(row),status: :created
  end
  def submission
    plan,item,lp,api,cid,binding,uid=context!
    if item['kind']=='tam'
      raise OperationWriter::Invalid,'Kerjakan TAM melalui Canvas' if request.post?
      rows=api.request('GET',"/api/v1/courses/#{cid}/quizzes/#{binding.remote_id}/submissions?as_user_id=#{uid}").fetch('quiz_submissions').select { |x| x['user_id'].to_s==uid }
      current=rows.max_by { |x|x['attempt'].to_i }
      capture(plan,item,lp,current) if current && current['attempt'].to_i>0
      return render json:{submission:current,source:'Canvas',percent:current && current['score'] && current['score'].to_f/item['questions'].length*100,aggregate_score:nil}
    end
    if request.post?
      raise OperationWriter::Forbidden,'Pengumpulan hanya oleh warga belajar pemilik bukti' unless lp.membership_id==@scope.membership_id && @scope.roles.include?('warga_belajar')
      text=params.require(:body).to_s
      references=Array(params[:evidence_references]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      raise OperationWriter::Invalid,'Bukti wajib memuat analisis minimal dua teks yang berbeda' if item['evidence_min_texts'].to_i>references.size
      raise OperationWriter::Invalid,'Jawaban terlalu panjang' if text.bytesize>100_000 || references.any? { |x| x.bytesize>2000 }
      body=text+"\n\nBukti/teks: "+references.join("\n")
      api.request('POST',"/api/v1/courses/#{cid}/assignments/#{binding.remote_id}/submissions?as_user_id=#{uid}",{'submission'=>{'submission_type'=>'online_text_entry','body'=>body}})
    end
    result=api.request('GET',"/api/v1/courses/#{cid}/assignments/#{binding.remote_id}/submissions/#{uid}?include[]=submission_history&include[]=submission_comments&include[]=rubric_assessment")
    capture(plan,item,lp,result)
    render json:{submission:result,source:'Canvas',plan_version:plan.version}
  end
  def grade
    plan,item,lp,api,cid,binding,uid=context!;tutor!(plan)
    raise OperationWriter::Invalid,'TAM dinilai Canvas; jangan menggantinya dengan skor lokal' if item['kind']=='tam'
    feedback=params.require(:feedback).to_s
    raise OperationWriter::Invalid,'Umpan balik wajib menjelaskan tindak lanjut' if feedback.blank? || feedback.bytesize>20_000
    scores=params.require(:criteria_scores).permit!.to_h
    score=AssessmentRules.score(item,scores)
    # Attribution and permission use the assigned Canvas tutor, not the admin token identity.
    teacher_uid=canvas_user_id(api_instance(plan),@scope.membership_id)
    assignment=api.request('GET',"/api/v1/courses/#{cid}/assignments/#{binding.remote_id}")
    native=Array(assignment['rubric'])
    rubric=item.fetch('rubric').to_h do |criterion|
      match=native.select { |r|r['description']==criterion['description'] }
      raise OperationWriter::Invalid,'Rubrik Canvas berbeda dari versi rancangan' unless match.length==1 && match.first['points'].to_f==criterion['points'].to_f
      [match.first.fetch('id'),{'points'=>scores.fetch(criterion['key']),'comments'=>feedback}]
    end
    before=api.request('GET',"/api/v1/courses/#{cid}/assignments/#{binding.remote_id}/submissions/#{uid}")
    raise OperationWriter::Invalid,'Belum ada pekerjaan untuk dinilai' unless before['attempt'].to_i>0
    result=api.request('PUT',"/api/v1/courses/#{cid}/assignments/#{binding.remote_id}/submissions/#{uid}?as_user_id=#{teacher_uid}",{'submission'=>{'posted_grade'=>score[:points].to_s},'rubric_assessment'=>rubric,'comment'=>{'text_comment'=>feedback}})
    capture(plan,item,lp,result)
    render json:{submission:result,calculation:score,source:'Canvas',academic_mastery_decision:false}
  end
  def release_tam
    plan,item,lp,api,cid,binding,uid=context!;tutor!(plan)
    previous_resource=plan.blueprint.dig('policy','prerequisite_resource_id')
    if previous_resource
      previous=AssessmentPlan.where(pkbm_id:@scope.pkbm_id,delivery_id:plan.delivery_id,learning_resource_id:previous_resource,status:'published')
      decision=actions.where(assessment_plan_id:previous.select(:id),learner_program_id:lp.id,action:'module_review').order(:created_at).last
      raise OperationWriter::Invalid,'Modul sebelumnya belum ditelaah siap lanjut oleh tutor' unless decision && decision.payload['decision']=='lanjut'
    end
    prerequisite_keys=if item['kind']=='tam'
      plan.blueprint['items'].select { |i|%w[assignment practice].include?(i['kind']) }.map { |i|i['key'] }
    elsif Array(item['mapping_keys']).include?('MAP-09')
      ['MAP-08-work']
    elsif Array(item['mapping_keys']).include?('MAP-10')
      ['MAP-08-work','MAP-09-work']
    else []
    end
    prerequisite_keys.each do |key|
      rule=plan.blueprint['items'].find { |i|i['key']==key }
      source=CanvasBinding.find_by!(pkbm_id:@scope.pkbm_id,object_kind:'assignment',local_key:"#{plan.id}:#{key}",remote_context:cid)
      submission=api.request('GET',"/api/v1/courses/#{cid}/assignments/#{source.remote_id}/submissions/#{uid}")
      max=rule.fetch('rubric').sum { |c|c['points'] }
      raise OperationWriter::Invalid,'Unit/bukti prasyarat belum mencapai 70; lakukan pembelajaran ulang' unless submission['score'].present? && submission['score'].to_f/max*100>=70
      raise OperationWriter::Invalid,'Produk perlu direvisi setelah umpan balik' if rule['requires_revision'] && submission['attempt'].to_i<2
    end
    unless item['kind']=='tam'
      path="/api/v1/courses/#{cid}/assignments/#{binding.remote_id}/overrides"
      override=api.list(path).find { |x|Array(x['student_ids']).map(&:to_s).include?(uid) }
      api.request('POST',path,{'assignment_override'=>{'student_ids'=>[uid.to_i],'title'=>"Pembelajaran untuk warga belajar #{uid}"}}) unless override
      return render json:{released:true,scope:'warga belajar yang dipilih',kind:item['kind']}
    end
    other_plans=AssessmentPlan.where(pkbm_id:@scope.pkbm_id,learning_resource_id:plan.learning_resource_id).where.not(id:plan.id)
    prior_attempts=AssessmentAttempt.where(pkbm_id:@scope.pkbm_id,assessment_plan_id:other_plans.select(:id),learner_program_id:lp.id,item_key:item['key'])
    raise OperationWriter::Invalid,'Versi baru tidak mereset kesempatan TAM; tutor perlu menelaah riwayat lintas versi' if prior_attempts.exists?
    quiz=api.request('GET',"/api/v1/courses/#{cid}/quizzes/#{binding.remote_id}")
    aid=quiz.fetch('assignment_id')
    path="/api/v1/courses/#{cid}/assignments/#{aid}/overrides"
    override=api.list(path).find { |x|Array(x['student_ids']).map(&:to_s).include?(uid) }
    api.request('POST',path,{'assignment_override'=>{'student_ids'=>[uid.to_i],'title'=>"Uji diminta warga belajar #{uid}"}}) unless override
    result=api.request('PUT',"/api/v1/courses/#{cid}/quizzes/#{binding.remote_id}",{'quiz'=>{'published'=>true,'only_visible_to_overrides'=>true}})
    render json:{released:true,scope:'warga belajar yang dipilih melalui assignment override',quiz:result}
  end
  def retry_tam
    plan,item,lp,api,cid,binding,uid=context!;tutor!(plan)
    raise OperationWriter::Invalid,'Instrumen bukan TAM BId' unless item['kind']=='tam' && plan.blueprint['subject']=='BID'
    plan.with_lock do
      raise OperationWriter::Invalid,'Kesempatan mengulang sudah diberikan' if actions.where(assessment_plan_id:AssessmentPlan.where(pkbm_id:@scope.pkbm_id,learning_resource_id:plan.learning_resource_id).select(:id),learner_program_id:lp.id,item_key:item['key'],action:'tam_retry').exists?
      rows=api.request('GET',"/api/v1/courses/#{cid}/quizzes/#{binding.remote_id}/submissions?as_user_id=#{uid}").fetch('quiz_submissions').select { |x| x['user_id'].to_s==uid }
      current=rows.max_by { |x| x['attempt'].to_i }
      total=item.fetch('questions').length
      raise OperationWriter::Invalid,'Ulangan hanya sesudah TAM pertama selesai dan nilai di bawah 70' unless current && current['attempt'].to_i==1 && current['workflow_state']=='complete' && current['score'].present? && current['score'].to_f/total*100<70
      payload={'quiz_extensions'=>[{'user_id'=>uid.to_i,'extra_attempts'=>1}]}
      api.request('POST',"/api/v1/courses/#{cid}/quizzes/#{binding.remote_id}/extensions",payload)
      AssessmentAction.create!(id:SecureRandom.uuid,pkbm_id:@scope.pkbm_id,assessment_plan_id:plan.id,learner_program_id:lp.id,item_key:item['key'],action:'tam_retry',actor_id:@scope.membership_id,payload:{source_submission:current,extra_attempts:1,recap:'per_attempt_no_aggregate'})
    end
    render json:{extra_attempts:1,maximum_attempts:2,aggregate_score:nil}
  end
  def review_module
    plan=plan!;tutor!(plan)
    lp=@scope.records('learner_programs').find(params.require(:learner_program_id))
    raise ActiveRecord::RecordNotFound unless @scope.base('delivery_enrollments').where(delivery_id:plan.delivery_id,learner_program_id:lp.id,status:'active').exists? && plan.status=='published'
    reason=params.require(:reason).to_s.strip
    raise OperationWriter::Invalid,'Keputusan memerlukan alasan dan tindak lanjut tutor' if reason.blank?
    evidence=attempts.where(assessment_plan_id:plan.id,learner_program_id:lp.id).order(:captured_at).to_a.group_by(&:item_key).transform_values(&:last)
    raise OperationWriter::Invalid,'Belum ada bukti Canvas yang ditelaah' if evidence.empty?
    pathway=params.require(:pathway).to_s
    regular=plan.blueprint.fetch('items').select { |i| %w[assignment practice].include?(i['kind']) }
    graded=regular.all? { |i| evidence[i['key']]&.snapshot&.dig('score').present? }
    maximum=regular.sum { |i|i.fetch('rubric').sum { |c|c.fetch('points') } }
    percent=graded ? regular.sum { |i|evidence[i['key']].snapshot['score'].to_f }/maximum*100 : nil
    candidate=false
    if plan.blueprint['subject']=='MTK'
      candidate=case pathway
      when 'complete_procedure' then graded && percent==100 && params[:procedure_verified]==true
      when 'assignment_75' then graded && percent>=75
      when 'placement_75'
        item=plan.blueprint['items'].find { |i|i['kind']=='placement' }; row=item && evidence[item['key']]; max=item && item['rubric'].sum { |c|c['points'] }; row && row.snapshot['score'].present? && row.snapshot['score'].to_f/max*100>=75
      else false
      end
    else
      raise OperationWriter::Invalid,'Gunakan telaah unit dan produk Bahasa Indonesia' unless pathway=='bid_unit_product_review'
      candidate=regular.all? do |i|
        row=evidence[i['key']];max=i.fetch('rubric').sum { |c|c.fetch('points') }
        row && row.snapshot['score'].present? && row.snapshot['score'].to_f/max*100>=70 && (!i['requires_revision'] || row.attempt>=2)
      end
      tam=plan.blueprint['items'].find { |i|i['kind']=='tam' };row=tam && evidence[tam['key']]
      candidate &&= row && row.snapshot['workflow_state']=='complete' && row.snapshot['score'].present? && row.snapshot['score'].to_f/tam['questions'].length*100>=70
    end
    requested=params.require(:decision).to_s
    raise OperationWriter::Invalid,'Keputusan harus lanjut atau pendampingan' unless %w[lanjut pendampingan].include?(requested)
    raise OperationWriter::Invalid,'Bukti belum memenuhi jalur; rencanakan pendampingan' if requested=='lanjut' && !candidate
    # Different/below-threshold evidence is explicitly acknowledged, never hidden by OR.
    conflict=plan.blueprint['items'].any? do |i|
      e=evidence[i['key']]; max=i['kind']=='tam' ? i['questions'].length : i.fetch('rubric').sum { |c|c['points'] }
      e && e.snapshot['score'].present? && e.snapshot['score'].to_f/max*100<(plan.blueprint['subject']=='MTK' ? 75 : 70)
    end
    raise OperationWriter::Invalid,'Tutor perlu mencatat telaah konflik bukti' if conflict && params[:conflict_review].to_s.strip.blank?
    row=AssessmentAction.create!(id:SecureRandom.uuid,pkbm_id:@scope.pkbm_id,assessment_plan_id:plan.id,learner_program_id:lp.id,item_key:'module',action:'module_review',actor_id:@scope.membership_id,payload:{pathway:pathway,decision:requested,reason:reason,procedure_verified:params[:procedure_verified]==true,conflict_review:params[:conflict_review].to_s,assignment_percent:percent,evidence_ids:evidence.values.map(&:id),academic_mastery:false,skk_awarded:false})
    render json:{review:row,academic_mastery_decision:false,skk_awarded:false}
  end
  private
  def plan!
    AssessmentPlan.where(pkbm_id:@scope.pkbm_id,delivery_id:@scope.records('deliveries').select(:id)).find(params[:id])
  end
  def staff!(plan)
    raise OperationWriter::Forbidden,'Rancangan hanya dikelola pengelola atau tutor yang ditugaskan' unless @scope.manager? || (@scope.tutor? && @scope.staff_deliveries.where(id:plan.delivery_id).exists?)
  end
  def tutor!(plan)
    raise OperationWriter::Forbidden,'Penilaian hanya oleh tutor yang ditugaskan' unless @scope.tutor? && @scope.staff_deliveries.where(id:plan.delivery_id).exists?
  end
  def attempts
    rows=AssessmentAttempt.where(pkbm_id:@scope.pkbm_id)
    return rows if @scope.manager? || @scope.tutor?
    rows.where(learner_program_id:@scope.own_programs.select(:id))
  end
  def actions
    rows=AssessmentAction.where(pkbm_id:@scope.pkbm_id)
    return rows if @scope.manager? || @scope.tutor?
    rows.where(learner_program_id:@scope.own_programs.select(:id))
  end
  def serialize_plan(plan)
    bp=plan.blueprint.deep_dup
    unless @scope.manager? || @scope.tutor?
      bp['items']&.each { |x| x.delete('questions') }
    end
    instance=CanvasInstance.find_by(pkbm_id:@scope.pkbm_id)
    bp['items']&.each do |item|
      remote=instance && CanvasBinding.find_by(pkbm_id:@scope.pkbm_id,canvas_instance_id:instance.id,object_kind:item['kind']=='tam' ? 'quiz' : 'assignment',local_key:"#{plan.id}:#{item['key']}")
      item['canvas_url']=remote && "#{instance.public_base_url}/courses/#{remote.remote_context}/#{item['kind']=='tam' ? 'quizzes' : 'assignments'}/#{remote.remote_id}"
    end
    binding=CanvasBinding.where(pkbm_id:@scope.pkbm_id,object_kind:'course',local_key:plan.delivery_id).first
    plan.attributes.merge('blueprint'=>bp,'canvas_course_id'=>binding&.remote_id)
  end
  def validate_targets!(plan,bp)
    c=ActiveRecord::Base.connection
    components=@scope.base('design_components').where(learning_design_version_id:@scope.base('deliveries').find(plan.delivery_id).learning_design_version_id).pluck(:curriculum_component_id)
    mapped=c.select_values("SELECT curriculum_component_id FROM resource_components WHERE learning_resource_id=#{c.quote(plan.learning_resource_id)}")
    raise OperationWriter::Invalid,'Bahan di luar komponen rancangan' if (components & mapped).empty?
    units=c.select_values("SELECT id FROM resource_units WHERE learning_resource_id=#{c.quote(plan.learning_resource_id)}")
    raise OperationWriter::Invalid,'Unit di luar bahan modul' unless Array(bp['units']).all? { |u|units.include?(u['resource_unit_id']) }
    resource=OperationWriter.new(@scope).catalog('learning_resources',plan.learning_resource_id)
    expected=resource['catalog_key'].include?('MTK') ? 'MTK' : 'BID'
    raise OperationWriter::Invalid,'Jenis aturan berbeda mata pelajaran bahan' unless bp['subject']==expected
    allowed=c.select_values("SELECT id FROM learning_targets WHERE curriculum_component_id IN (#{components.map { |x|c.quote(x) }.join(',')})")
    Array(bp['items']).each do |x|
      raise OperationWriter::Invalid,'Target di luar rancangan' unless (Array(x['target_ids'])-allowed).empty?
      raise OperationWriter::Invalid,'MAP-04 tidak boleh menjadi klaim penilaian KD 3.4/4.4' if Array(x['mapping_keys']).include?('MAP-04') && Array(x['target_ids']).any? { |id| ['3.4','4.4'].include?(OperationWriter.new(@scope).catalog('learning_targets',id)['source_code']) }
    end
  end
  def api_instance(plan)
    i=CanvasInstance.find_by!(pkbm_id:@scope.pkbm_id,enabled:true)
    raise OperationWriter::Invalid,'Token Canvas diperlukan untuk membaca/mengirim hasil' unless i.credentials['access_token'].present?
    i
  end
  def canvas_user_id(instance,membership_id)
    person=@scope.base('pkbm_memberships').find(membership_id).person_id
    CanvasBinding.find_by!(pkbm_id:@scope.pkbm_id,canvas_instance_id:instance.id,object_kind:'user',local_key:person).remote_id
  end
  def context!
    plan=plan!
    raise ActiveRecord::RecordNotFound unless plan.status=='published'
    item=plan.blueprint.fetch('items').find { |x|x['key']==params[:item_key].to_s } || raise(ActiveRecord::RecordNotFound)
    lp=@scope.records('learner_programs').find(params.require(:learner_program_id))
    raise ActiveRecord::RecordNotFound unless lp.status=='active' && @scope.base('delivery_enrollments').where(delivery_id:plan.delivery_id,learner_program_id:lp.id,status:'active').exists?
    instance=api_instance(plan);api=CanvasApi.new(instance)
    cid=CanvasBinding.find_by!(pkbm_id:@scope.pkbm_id,canvas_instance_id:instance.id,object_kind:'course',local_key:plan.delivery_id).remote_id
    binding=CanvasBinding.find_by!(pkbm_id:@scope.pkbm_id,canvas_instance_id:instance.id,object_kind:item['kind']=='tam' ? 'quiz' : 'assignment',local_key:"#{plan.id}:#{item['key']}",remote_context:cid)
    [plan,item,lp,api,cid,binding,canvas_user_id(instance,lp.membership_id)]
  end
  def capture(plan,item,lp,snapshot)
    return unless snapshot['id'].present? && snapshot['attempt'].to_i>0
    previous=AssessmentAttempt.where(pkbm_id:@scope.pkbm_id,assessment_plan_id:plan.id,item_key:item['key'],learner_program_id:lp.id).order(:captured_at).last
    return if previous && previous.snapshot==snapshot
    AssessmentAttempt.create!(id:SecureRandom.uuid,pkbm_id:@scope.pkbm_id,assessment_plan_id:plan.id,item_key:item['key'],learner_program_id:lp.id,canvas_submission_id:snapshot.fetch('id').to_s,attempt:[snapshot['attempt'].to_i,1].max,snapshot:snapshot,captured_by:@scope.membership_id)
  end
end
