# Local-only exception for the pinned IdP's public key and discovery endpoints.
# Do not disable CanvasHttp's private-network protections globally.
require 'canvas_http'
module PkbmLocalOidcHttp
  def validate_url(value, **options)
    if Rails.env.development?
      uri = URI.parse(value.to_s)
      if uri.scheme == 'http' && uri.host == 'identity' && uri.port == 8080 &&
          uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? &&
          ['/realms/pkbm/protocol/openid-connect/certs', '/realms/pkbm/.well-known/openid-configuration'].include?(uri.path)
        return super(value, **options.merge(check_host: false))
      end
    end
    super
  end
end
CanvasHttp.singleton_class.prepend(PkbmLocalOidcHttp)

# Canvas' generic login adapter drops target_link_uri before dispatching to
# OpenID Connect. Preserve the course target while retaining expected_user_id
# in the native login session. The provider validates the return path itself.
module PkbmOidcCourseReturn
  def redirect_to_specific_provider(auth_type)
    if auth_type == 'openid_connect' && params[:target_link_uri].present?
      redirect_to url_for({controller: 'login/openid_connect', action: :new}
        .merge(params.permit(:id, :login_hint, :target_link_uri).to_unsafe_h))
    else
      super
    end
  end
end
Rails.application.config.to_prepare do
  LoginController.prepend(PkbmOidcCourseReturn) unless LoginController.ancestors.include?(PkbmOidcCourseReturn)
end

# Return this local PKBM provider to the same central login form as the portal.
# Other authentication providers retain Canvas' native logout destination.
module PkbmOidcLogoutReturn
  def post_logout_redirect_params(controller, redirect_options: {})
    result = super
    if Rails.env.development? && idp_entity_id == 'http://127.0.0.1:8082/realms/pkbm'
      result[:post_logout_redirect_uri] = 'http://127.0.0.1:3000/auth/login'
    end
    result
  end
end
Rails.application.config.to_prepare do
  AuthenticationProvider::OpenIDConnect.prepend(PkbmOidcLogoutReturn) unless AuthenticationProvider::OpenIDConnect.ancestors.include?(PkbmOidcLogoutReturn)
end
