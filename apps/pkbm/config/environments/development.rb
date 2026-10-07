Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.secret_key_base = ENV.fetch("PKBM_SECRET_KEY_BASE")
end
