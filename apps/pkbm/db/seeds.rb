require "json"
data = JSON.parse(File.read(Rails.root.join("db/seeds/catalog.json")))
expected = %w[source_documents source_references curriculum_versions curriculum_levels curriculum_groups specialization_tracks curriculum_components component_relations academic_frameworks learning_targets framework_targets framework_topics framework_activities framework_activity_targets source_findings learning_resources resource_components resource_units resource_target_mappings source_policy_statements]
raise "Unexpected seed collection" unless (data.fetch("tables").keys - expected).empty?
connection = ActiveRecord::Base.connection
ActiveRecord::Base.transaction do
  connection.execute("SELECT pg_advisory_xact_lock(73131007)")
  data.fetch("tables").each do |table, rows|
    rows.each do |row|
      columns = row.keys.map { |key| connection.quote_column_name(key) }.join(", ")
      values = row.values.map { |value| connection.quote(value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value) }.join(", ")
      # Stable UUIDs and natural catalog keys make retries insert-only. Existing
      # content is never silently rewritten; changed source data needs a new version.
      existing = connection.select_one("SELECT * FROM #{connection.quote_table_name(table)} WHERE id = #{connection.quote(row.fetch('id'))}")
      if existing
        row.each do |key, wanted|
          actual = existing[key]
          actual = JSON.parse(actual) if (wanted.is_a?(Hash) || wanted.is_a?(Array)) && actual.is_a?(String)
          raise "Seed changed: #{table}/#{row.fetch('catalog_key')}/#{key}; create a new catalog version" unless actual == wanted || (wanted.is_a?(Numeric) && actual.to_s == wanted.to_s)
        end
      else
        connection.execute("INSERT INTO #{connection.quote_table_name(table)} (#{columns}) VALUES (#{values})")
      end
    end
  end
end
puts "Catalog seed applied; no academic decisions created."
