# Scope always starts at the authenticated tenant. Client tenant IDs are ignored.
class OperationScope
  attr_reader :pkbm_id, :membership_id, :roles
  def initialize(pkbm_id, membership_id)
    @pkbm_id, @membership_id = pkbm_id, membership_id
    @roles = base("role_assignments").where(membership_id: membership_id).pluck(:role)
  end

  def base(table)
    OperationRecord.for(table).where(pkbm_id: pkbm_id)
  end

  def manager? = roles.include?("pengelola")
  def tutor? = (roles & %w[tutor instruktur]).any?
  def own_programs = base("learner_programs").where(membership_id: membership_id)
  def staff_deliveries = tutor? ? base("deliveries").where(id: base("delivery_staff").where(membership_id: membership_id).select(:delivery_id)) : base("deliveries").none
  def learner_deliveries = base("deliveries").where(id: base("delivery_enrollments").where(learner_program_id: own_programs.select(:id), status: "active").select(:delivery_id), status: "active")
  def deliveries = base("deliveries").where(id: (tutor? ? staff_deliveries : base("deliveries").none).pluck(:id) + learner_deliveries.pluck(:id))
  def designs = base("learning_design_versions").where(id: deliveries.select(:learning_design_version_id)).or(base("learning_design_versions").where(owner_membership_id: membership_id))

  def records(table)
    return base(table) if manager?
    relevant_programs = own_programs.pluck(:id)
    relevant_programs += base("delivery_enrollments").where(delivery_id: staff_deliveries.select(:id)).pluck(:learner_program_id) if tutor?
    programs = base("learner_programs").where(id: relevant_programs)
    members = programs.pluck(:membership_id) + [membership_id] + base("delivery_staff").where(delivery_id: deliveries.select(:id)).pluck(:membership_id)
    case table
    when "people" then base(table).where(id: base("pkbm_memberships").where(id: members).select(:person_id))
    when "pkbm_memberships" then base(table).where(id: members)
    when "role_assignments" then base(table).where(membership_id: membership_id)
    when "learner_programs" then programs
    when "program_offerings" then base(table).where(id: programs.pluck(:program_offering_id) + designs.pluck(:program_offering_id))
    when "learning_groups" then base(table).where(id: deliveries.select(:learning_group_id))
    when "group_memberships" then base(table).where(learner_program_id: programs.select(:id))
    when "learning_design_versions" then designs
    when "design_components", "learning_activities" then base(table).where(learning_design_version_id: designs.select(:id))
    when "activity_targets" then base(table).where(learning_activity_id: records("learning_activities").select(:id))
    when "deliveries" then deliveries
    when "delivery_staff" then base(table).where(delivery_id: deliveries.select(:id))
    when "delivery_enrollments" then base(table).where(learner_program_id: own_programs.select(:id)).or(base(table).where(delivery_id: staff_deliveries.select(:id)))
    when "learning_plans" then base(table).where(learner_program_id: own_programs.select(:id), status: "active").or(tutor? ? base(table).where(learner_program_id: relevant_programs) : base(table).none)
    when "learning_plan_items" then base(table).where(learning_plan_id: records("learning_plans").select(:id), delivery_id: deliveries.select(:id))
    when "learning_sessions" then base(table).where(delivery_id: deliveries.select(:id))
    else base(table).none
    end
  end
end
