require 'openssl'
require 'jwt'
require 'json'
checks=[]
key=OpenSSL::PKey::RSA.generate(2048)
jwk=JWT::JWK.new(key, 'validation-only')
claims={'iss'=>ENV.fetch('PKBM_OIDC_ISSUER'),'sub'=>'isolated-fixture','aud'=>ENV.fetch('PKBM_OIDC_CLIENT_ID'),'iat'=>Time.now.to_i,'exp'=>Time.now.to_i+120,'nonce'=>'fixture-nonce'}
client=OidcClient.new
rejection = ->(label, altered) do
  client.define_singleton_method(:fetch) do |path, data=nil|
    path.end_with?('/certs') ? {keys:[jwk.export]} : {'id_token'=>JWT.encode(altered, key, 'RS256', kid: jwk.kid)}
  end
  begin
    client.redeem(code:'fixture-code',verifier:'fixture-verifier',nonce:'fixture-nonce')
    checks << {name:label,passed:false}
  rescue OidcClient::Invalid
    checks << {name:label,passed:true}
  end
end
[['issuer',{'iss'=>'http://foreign.invalid'}],['audience',{'aud'=>'foreign-client'}],['expiry',{'exp'=>Time.now.to_i-10}],['nonce',{'nonce'=>'wrong'}],['future issuance',{'iat'=>Time.now.to_i+90}],['missing subject',{'sub'=>''}],['authorized party',{'azp'=>'foreign-client'}]].each {|label,patch| rejection.call(label+' rejected',claims.merge(patch))}
client.define_singleton_method(:fetch) do |path,data=nil|
 path.end_with?('/certs') ? {keys:[jwk.export]} : {'id_token'=>JWT.encode(claims,key,'RS256',kid:jwk.kid)}
end
checks << {name:'valid signed assertion accepted',passed:client.redeem(code:'fixture-code',verifier:'fixture-verifier',nonce:'fixture-nonce')['sub']=='isolated-fixture'}
foreign_key=OpenSSL::PKey::RSA.generate(2048)
client.define_singleton_method(:fetch) do |path,data=nil|
 path.end_with?('/certs') ? {keys:[jwk.export]} : {'id_token'=>JWT.encode(claims,foreign_key,'RS256',kid:jwk.kid)}
end
begin
 client.redeem(code:'fixture-code',verifier:'fixture-verifier',nonce:'fixture-nonce');checks << {name:'invalid signature rejected',passed:false}
rescue OidcClient::Invalid
 checks << {name:'invalid signature rejected',passed:true}
end
logout_base={'iss'=>client.issuer,'aud'=>client.client_id,'iat'=>Time.now.to_i,'exp'=>Time.now.to_i+120,'jti'=>'isolated-jti','sid'=>'isolated-sid','events'=>{'http://schemas.openid.net/event/backchannel-logout'=>{}}}
client.define_singleton_method(:fetch) {|path,data=nil| {keys:[jwk.export]} }
checks << {name:'valid logout assertion accepted',passed:client.logout_claims(JWT.encode(logout_base,key,'RS256',kid:jwk.kid))['sid']=='isolated-sid'}
[['logout nonce',{'nonce'=>'forbidden'}],['logout missing session',{'sid'=>nil}],['logout event',{'events'=>{}}],['logout stale issuance',{'iat'=>Time.now.to_i-600}],['logout audience',{'aud'=>'foreign'}]].each do |label,patch|
 begin
  client.logout_claims(JWT.encode(logout_base.merge(patch),key,'RS256',kid:jwk.kid));checks << {name:label+' rejected',passed:false}
 rescue OidcClient::Invalid
  checks << {name:label+' rejected',passed:true}
 end
end
# Controller checks use isolated flows inside a rolled-back transaction.
OidcClient.prepend(Module.new { def redeem(**); raise OidcClient::Invalid; end })
ActiveRecord::Base.transaction do
 build_flow = -> {
  session=ActionDispatch::Integration::Session.new(Rails.application);session.host!('127.0.0.1:3000');session.get('/auth/login',params:{redirect_uri:'https://foreign.invalid/',next:'https://foreign.invalid/'})
  query=URI.decode_www_form(URI(session.response.location).query).to_h
  checks << {name:'external callback override ignored',passed:query['redirect_uri']==client.callback}
  state=query.fetch('state')
  [session,state]
 }
 session=ActionDispatch::Integration::Session.new(Rails.application);session.host!('127.0.0.1:3000');session.get('/auth/callback',params:{state:'missing',code:'fixture'})
 checks << {name:'callback missing flow rejected',passed:session.response.status==401}
 session,state=build_flow.call;session.get('/auth/callback',params:{state:'wrong',code:'fixture'})
 checks << {name:'callback state mismatch rejected',passed:session.response.status==401}
 session,state=build_flow.call;flow=IdentityLoginFlow.find_by!(state_digest:Digest::SHA256.hexdigest(state));flow.update!(expires_at:1.minute.ago)
 session.get('/auth/callback',params:{state:state,code:'fixture'})
 checks << {name:'callback expired flow rejected',passed:session.response.status==401 && flow.reload.used_at.nil?}
 session,state=build_flow.call;cookie=session.cookies.to_hash.map{|k,v| "#{k}=#{v}"}.join('; ')
 session.get('/auth/callback',params:{state:state,code:'fixture'})
 flow=IdentityLoginFlow.find_by!(state_digest:Digest::SHA256.hexdigest(state))
 checks << {name:'failed exchange consumes state safely',passed:session.response.status==401 && flow.used_at.present?}
 replay=ActionDispatch::Integration::Session.new(Rails.application);replay.host!('127.0.0.1:3000');replay.get('/auth/callback',params:{state:state,code:'fixture'},headers:{'Cookie'=>cookie})
 checks << {name:'callback replay rejected',passed:replay.response.status==401}
 raise ActiveRecord::Rollback
end
puts JSON.pretty_generate(passed:checks.count{|c|c[:passed]},failed:checks.count{|c|!c[:passed]},scope:'OIDC assertions and controller callback guards with isolated RSA keys, rolled-back flows and failed-exchange stub',checks:checks)
raise 'Assertion validation failed' if checks.any?{|c|!c[:passed]}
