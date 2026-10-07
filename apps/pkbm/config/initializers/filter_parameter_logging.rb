Rails.application.config.filter_parameters += %i[password password_digest token access_token shared_secret credentials credentials_encrypted oauth_signature code]
Rails.application.config.filter_parameters += %i[id_token refresh_token client_secret code_verifier nonce state pkbm_identity_session pkbm_oidc_flow]

Rails.application.config.filter_parameters += [:id_token_hint, :pkbm_logout_hint]
