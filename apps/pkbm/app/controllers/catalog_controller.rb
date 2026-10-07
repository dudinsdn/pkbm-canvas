class CatalogController < ActionController::API
  COLLECTIONS = %w[source_documents source_references curriculum_versions curriculum_levels curriculum_groups specialization_tracks curriculum_components component_relations academic_frameworks learning_targets framework_targets framework_topics framework_activities framework_activity_targets source_findings learning_resources resource_components resource_units resource_target_mappings source_policy_statements].freeze

  def index
    counts = COLLECTIONS.to_h { |table| [table, connection.select_value("SELECT count(*) FROM #{connection.quote_table_name(table)}").to_i] }
    render json: { scope: "katalog_acuan_bersama", runtime_stage: "katalog_awal", counts: counts, coverage: connection.select_all("SELECT catalog_key, name, coverage_status FROM curriculum_components ORDER BY catalog_key").to_a, academic_decisions_enabled: false }
  end

  def collection
    table = params[:collection]
    return render json: { error: "Koleksi tidak tersedia" }, status: :not_found unless COLLECTIONS.include?(table)
    limit = [[params.fetch(:limit, 50).to_i, 1].max, 100].min
    offset = [params.fetch(:offset, 0).to_i, 0].max
    rows = connection.select_all("SELECT * FROM #{connection.quote_table_name(table)} ORDER BY catalog_key LIMIT #{limit} OFFSET #{offset}").to_a
    render json: { collection: table, limit: limit, offset: offset, records: rows }
  end

  private

  def connection
    ActiveRecord::Base.connection
  end
end
