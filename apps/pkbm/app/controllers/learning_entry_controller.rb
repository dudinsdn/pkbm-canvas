require 'uri'
class LearningEntryController < OperationsController
  include ActionController::Cookies
  rescue_from ActiveRecord::RecordNotFound do
    render json: {error: 'Akses pembelajaran belum siap. Hubungi pengelola PKBM.'}, status: :conflict
  end
  def show
    raise ActiveRecord::RecordNotFound unless ENV['PKBM_SSO_ENABLED'] == 'true'
    delivery = @scope.records('deliveries').find(params[:id])
    session = IdentitySessionStore.resolve!(cookies[:pkbm_identity_session])
    instance = CanvasInstance.find_by!(pkbm_id: @scope.pkbm_id, enabled: true)
    identity = CanvasIdentityLink.find_by!(identity_account_id: session.identity_account_id,
      deployment_key: 'pkbm-canvas-local', root_account_id: instance.root_account_id, status: 'ready')
    course = CanvasBinding.find_by!(canvas_instance_id: instance.id, object_kind: 'course', local_key: delivery.id)
    member = @scope.base('pkbm_memberships').find(@scope.membership_id)
    user = CanvasBinding.find_by!(canvas_instance_id: instance.id, object_kind: 'user', local_key: member.person_id)
    raise ActiveRecord::RecordNotFound unless user.remote_id == identity.remote_user_id
    # expected_user_id prevents an existing Canvas session from bypassing the
    # provider. Do not set force_login, which would force another password.
    target = "/courses/#{course.remote_id}"
    query = URI.encode_www_form(expected_user_id: identity.remote_user_id,
      login_hint: identity.federated_identifier, target_link_uri: target)
    redirect_to "#{instance.public_base_url}/login/#{identity.authentication_provider_id}?#{query}", allow_other_host: true
  end
  def manage
    raise OperationWriter::Forbidden, 'Akses pengelola PKBM diperlukan' unless @scope.manager?
    session = IdentitySessionStore.resolve!(cookies[:pkbm_identity_session])
    instance = CanvasInstance.find_by!(pkbm_id: @scope.pkbm_id, enabled: true)
    access = CanvasManagementLink.find_by!(pkbm_id: @scope.pkbm_id, canvas_instance_id: instance.id,
      membership_id: @scope.membership_id, identity_account_id: session.identity_account_id, status: 'ready')
    identity = CanvasIdentityLink.find_by!(identity_account_id: session.identity_account_id,
      deployment_key: 'pkbm-canvas-local', root_account_id: instance.root_account_id, status: 'ready')
    account = CanvasBinding.find_by!(pkbm_id: @scope.pkbm_id, canvas_instance_id: instance.id, object_kind: 'account', local_key: @scope.pkbm_id)
    raise ActiveRecord::RecordNotFound unless access.remote_user_id == identity.remote_user_id && access.remote_account_id == account.remote_id && access.remote_account_id != instance.root_account_id.to_s
    query = URI.encode_www_form(expected_user_id: identity.remote_user_id,
      login_hint: identity.federated_identifier, target_link_uri: "/accounts/#{access.remote_account_id}")
    redirect_to "#{instance.public_base_url}/login/#{identity.authentication_provider_id}?#{query}", allow_other_host: true
  end
  private
  def authenticate!
    request.headers['Authorization'] = "Bearer #{cookies[:pkbm_identity_session]}"
    super
  end
end
