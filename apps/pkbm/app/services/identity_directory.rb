require 'net/http'
require 'json'
require 'uri'
class IdentityDirectory
  class Unavailable < StandardError; end
  def initialize
    @base = URI(ENV.fetch('PKBM_OIDC_BACKCHANNEL'))
    raise Unavailable, 'Konfigurasi layanan identitas tidak tersedia' unless @base.host == 'identity' && @base.port == 8080 && @base.path == '/realms/pkbm'
    result = request('POST', '/realms/pkbm/protocol/openid-connect/token', {
      grant_type: 'client_credentials', client_id: ENV.fetch('PKBM_IDP_PROVISION_CLIENT_ID'),
      client_secret: ENV.fetch('PKBM_IDP_PROVISION_CLIENT_SECRET')}, form: true)
    raise Unavailable, 'Layanan akun belum tersedia; hubungi pengelola' unless result.is_a?(Hash) && result['access_token'].is_a?(String) && result['access_token'].present?
    @token = result.fetch('access_token')
  rescue KeyError
    raise Unavailable, 'Konfigurasi layanan identitas tidak tersedia'
  end
  def create(username:, email:, name:, membership_id:)
    candidates = request('GET', '/admin/realms/pkbm/users?' + URI.encode_www_form(username: username, exact: true))
    if candidates.any?
      raise Unavailable, 'Identifier pengguna bertentangan' unless candidates.length == 1
      existing = user(candidates.first.fetch('id'))
      raise Unavailable, 'Identifier pengguna bertentangan' unless existing.dig('attributes','pkbm_membership_id') == [membership_id] && existing['email'] == email && existing['enabled']
      return existing.fetch('id')
    end
    request('POST', '/admin/realms/pkbm/users', {username: username, email: email, firstName: name, enabled: true,
      emailVerified: false, attributes: {pkbm_membership_id: [membership_id]}, requiredActions: ['VERIFY_EMAIL','UPDATE_PASSWORD']})
    rows = request('GET', '/admin/realms/pkbm/users?' + URI.encode_www_form(username: username, exact: true))
    raise Unavailable unless rows.length == 1
    rows.first.fetch('id')
  end
  def activate_email(subject)
    request('PUT', "/admin/realms/pkbm/users/#{subject}/execute-actions-email?" + URI.encode_www_form(client_id: 'pkbm-portal', redirect_uri: ENV.fetch('PKBM_PUBLIC_BASE_URL') + '/'), ['VERIFY_EMAIL','UPDATE_PASSWORD'])
  end
  def user(subject) = request('GET', "/admin/realms/pkbm/users/#{subject}")
  def logout(subject) = request('POST', "/admin/realms/pkbm/users/#{subject}/logout")
  def disable(subject)
    request('PUT', "/admin/realms/pkbm/users/#{subject}", {enabled: false})
    logout(subject)
  end
  private
  def request(method, path, data = nil, form: false)
    uri = URI("http://identity:8080#{path}")
    req = {'GET'=>Net::HTTP::Get,'POST'=>Net::HTTP::Post,'PUT'=>Net::HTTP::Put}.fetch(method).new(uri)
    req['Authorization'] = "Bearer #{@token}" if @token
    if form
      req.set_form_data(data)
    elsif data
      req['Content-Type'] = 'application/json'; req.body = JSON.generate(data)
    end
    http = Net::HTTP.new(uri.host, uri.port, nil); http.open_timeout = 5; http.read_timeout = 15
    response = http.request(req)
    raise Unavailable, 'Layanan akun belum tersedia; hubungi pengelola' unless response.is_a?(Net::HTTPSuccess)
    response.body.to_s.empty? ? nil : JSON.parse(response.body)
  rescue IOError, SystemCallError, SocketError, Timeout::Error, JSON::ParserError, KeyError
    raise Unavailable, 'Layanan akun belum tersedia; hubungi pengelola'
  end
end
