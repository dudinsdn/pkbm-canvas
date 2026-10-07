class OperationRecord < ActiveRecord::Base
  self.abstract_class = true
  TABLES = %w[people pkbm_memberships role_assignments program_offerings learner_programs learning_groups group_memberships learning_design_versions design_components learning_activities activity_targets deliveries delivery_staff delivery_enrollments learning_plans learning_plan_items learning_sessions].freeze
  CLASSES = TABLES.to_h do |table|
    klass = Class.new(self) { self.table_name = table }
    const_set(table.camelize, klass)
    [table, klass]
  end.freeze
  FIELDS = {"people" => ["name", "email"],
    "pkbm_memberships" => ["person_id", "status"],
    "role_assignments" => ["membership_id", "role"],
    "program_offerings" => ["curriculum_version_id", "name", "period", "status"],
    "learner_programs" => ["program_offering_id", "membership_id", "curriculum_level_id", "specialization_track_id", "starts_on", "status"],
    "learning_groups" => ["program_offering_id", "name", "period"],
    "group_memberships" => ["learning_group_id", "learner_program_id", "starts_on", "ends_on"],
    "learning_design_versions" => ["program_offering_id", "owner_membership_id", "name", "version", "kind", "local_adjustment", "adjustment_origin", "status"],
    "design_components" => ["learning_design_version_id", "curriculum_component_id"],
    "learning_activities" => ["learning_design_version_id", "title", "position", "objective", "mode", "evidence_plan", "assessment_method", "local_adjustment"],
    "activity_targets" => ["learning_activity_id", "learning_target_id", "relation_type", "mapping_status"],
    "deliveries" => ["learning_design_version_id", "learning_group_id", "name", "period", "location", "status"],
    "delivery_staff" => ["delivery_id", "membership_id", "responsibility"],
    "delivery_enrollments" => ["delivery_id", "learner_program_id", "status"],
    "learning_plans" => ["learner_program_id", "version", "starts_on", "ends_on", "objective", "status"],
    "learning_plan_items" => ["learning_plan_id", "delivery_id", "learning_target_id", "position", "planned_on"],
    "learning_sessions" => ["delivery_id", "learning_activity_id", "starts_at", "mode", "planned_jp", "location"]}.freeze
  def self.for(table)
    CLASSES.fetch(table)
  end
end
