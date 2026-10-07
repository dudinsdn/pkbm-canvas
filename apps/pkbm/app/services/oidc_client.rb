require 'jwt'
require 'net/http'
require 'uri'
require 'json'
require 'digest'
require 'base64'
class OidcClient
  class Invalid < StandardError; end
  attr_reader :logout_id_token
  def issuer = ENV.fetch('PKBM_OIDC_ISSUER')
  def callback = ENV.fetch('PKBM_PUBLIC_BASE_URL') + '/auth/callback'
  def client_id = ENV.fetch('PKBM_OIDC_CLIENT_ID')
  def authorization(state:, nonce:, verifier:)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    issuer + '/protocol/openid-connect/auth?' + URI.encode_www_form(client_id: client_id, redirect_uri: callback,
      response_type: 'code', scope: 'openid', state: state, nonce: nonce, code_challenge: challenge, code_challenge_method: 'S256')
  end
  def redeem(code:, verifier:, nonce:)
    tokens = fetch('/protocol/openid-connect/token', {grant_type: 'authorization_code', code: code,
      redirect_uri: callback, client_id: client_id, client_secret: ENV.fetch('PKBM_OIDC_CLIENT_SECRET'), code_verifier: verifier})
    jwks = JWT::JWK::Set.new(fetch('/protocol/openid-connect/certs'))
    claims, = JWT.decode(tokens.fetch('id_token'), nil, true, algorithms: ['RS256'], jwks: jwks,
      verify_iss: true, iss: issuer, verify_aud: true, aud: client_id, verify_expiration: true,
      verify_iat: true, required_claims: %w[iss sub aud exp iat nonce])
    raise Invalid unless claims['nonce'].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(claims['nonce'], nonce)
    raise Invalid if claims['sub'].blank? || claims['iat'].to_i > Time.now.to_i + 30
    raise Invalid if (claims['aud'].is_a?(Array) && claims['aud'].length > 1 || claims.key?('azp')) && claims['azp'] != client_id
    @logout_id_token = tokens.fetch('id_token')
    claims
  rescue JWT::DecodeError, KeyError, ArgumentError
    raise Invalid, 'Jawaban layanan identitas tidak sah'
  end
  def logout_claims(token)
    jwks = JWT::JWK::Set.new(fetch('/protocol/openid-connect/certs'))
    claims, = JWT.decode(token, nil, true, algorithms: ['RS256'], jwks: jwks,
      verify_iss: true, iss: issuer, verify_aud: true, aud: client_id, verify_expiration: true,
      verify_iat: true, required_claims: %w[iss aud exp iat jti events])
    raise Invalid if claims.key?('nonce') || (claims['sid'].blank? && claims['sub'].blank?)
    raise Invalid unless claims['events'].is_a?(Hash) && claims['events']['http://schemas.openid.net/event/backchannel-logout'].is_a?(Hash)
    raise Invalid if claims['iat'].to_i > Time.now.to_i + 30 || claims['iat'].to_i < Time.now.to_i - 300
    claims
  rescue JWT::DecodeError, KeyError, ArgumentError
    raise Invalid, 'Logout token tidak sah'
  end
  private
  def fetch(path, data=nil)
    uri = URI(ENV.fetch('PKBM_OIDC_BACKCHANNEL') + path)
    raise Invalid unless uri.scheme == 'https' || (Rails.env.development? && uri.scheme == 'http' && uri.host == 'identity')
    req = data ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
    req.set_form_data(data) if data
    http = Net::HTTP.new(uri.host, uri.port, nil); http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 5; http.read_timeout = 10
    response = http.request(req)
    raise Invalid unless response.is_a?(Net::HTTPSuccess) && response.body.bytesize < 1_048_576
    JSON.parse(response.body)
  rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError
    raise Invalid, 'Layanan identitas belum tersedia'
  end
end
