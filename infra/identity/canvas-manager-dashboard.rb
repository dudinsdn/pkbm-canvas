# Presentation adapter for locally provisioned PKBM subaccount administrators.
# Canvas remains responsible for authentication, authorization and course data.
module PkbmManagerDashboard
  def user_dashboard
    if Rails.env.development? && (request.format.html? || request.format == '*/*') && !request.path.start_with?('/api/') && @current_user && !session[:become_user_id]
      memberships = @current_user.account_users.active.preload(:account).to_a
      unless memberships.any? { |row| row.account.parent_account_id.nil? }
        accounts = memberships.map(&:account).select { |account| pkbm_managed_account?(account) }.uniq(&:id)
        return redirect_to("/accounts/#{accounts.first.id}") if accounts.length == 1
        return redirect_to('/accounts') if accounts.length > 1
      end
    end
    super
  end

  private
  def pkbm_managed_account?(account)
    account.parent_account_id.present? && account.sis_source_id.to_s.match?(/\Apkbm-([0-9a-f-]{36})-account-\1\z/)
  end
end

module PkbmManagerAccountHome
  def show
    if Rails.env.development? && (request.format.html? || request.format == '*/*') && !request.path.start_with?('/api/') && @current_user &&
        @account.parent_account_id.present? &&
        @account.sis_source_id.to_s.match?(/\Apkbm-([0-9a-f-]{36})-account-\1\z/) &&
        @account.account_users.active.where(user_id: @current_user.id).exists?
      return unless authorized_action(@account, @current_user, :read_course_list)
      @page_title = "Kelola pembelajaran · #{@account.name}"
      @pkbm_courses = @account.courses.where.not(workflow_state: 'deleted').order(:name).limit(12)
      @pkbm_course_count = @account.courses.where.not(workflow_state: 'deleted').count
      add_crumb 'Kelola pembelajaran'
      return render template: 'pkbm/manager_dashboard'
    end
    super
  end
end

Rails.application.config.to_prepare do
  UsersController.prepend(PkbmManagerDashboard) unless UsersController.ancestors.include?(PkbmManagerDashboard)
  AccountsController.prepend(PkbmManagerAccountHome) unless AccountsController.ancestors.include?(PkbmManagerAccountHome)
  AccountsController.prepend_view_path(Rails.root.join('config/pkbm_views'))
end
