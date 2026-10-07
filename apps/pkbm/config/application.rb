require_relative "boot"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
module Pkbm
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true
    config.public_file_server.enabled = true
    config.active_record.schema_format = :sql
    config.hosts = ["localhost", "127.0.0.1", "pkbm"]
  end
end
