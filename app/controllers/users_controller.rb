class UsersController < ApplicationController
  before_filter :load_resource, only: [:edit, :update, :assign_role, :unassign_role]

  def index
    return unless authorize_resource(@navigation_context.entity, (@navigation_context.entity.kind_of?(Institution) ? READ_INSTITUTION_USERS : READ_SITE_USERS))
    @users = User.within(@navigation_context.entity)
    @roles = Role.within(@navigation_context.entity).map{|r| {value: r.id, label: r.name}}
    apply_filters

    @date_options = date_options_for_filter
    @roles = check_access(Role, READ_ROLE).within(@navigation_context.entity)

    respond_to do |format|
      format.html
      format.csv do
        filename = "Users-#{DateTime.now.strftime('%Y-%m-%d-%H-%M-%S')}.csv"
        headers["Content-Type"] = "text/csv"
        headers["Content-disposition"] = "attachment; filename=#{filename}"
        self.response_body = build_csv
      end
    end

  end

  def edit
    @user_roles = @user.roles
    return unless @user_roles.any?{|role| authorize_resource(role, ASSIGN_USER_ROLE)}
    @user_roles = @user_roles.map{|r| {value: r.id, label: r.name}}
    @can_update = has_access?(User, UPDATE_USER)
  end

  def update
    return unless authorize_resource(@user, UPDATE_USER)
    return head :forbidden unless can_edit?

    message = 'User updated' if @user.update(user_params)
    redirect_to users_path, notice: message || 'There was a problem updating this user'
  end

  def create
    users = []
    @role = Role.find(params[:role])
    params[:users].split(',').each do |email|
      email = email.strip
      user = User.find_or_initialize_by(email: email)
      user.invite! unless user.persisted?
      user.roles << @role unless user.roles.include?(@role)
      ComputedPolicy.update_user(user)
    end
    render nothing: true
  end

  def assign_role
    @role = Role.find(params[:role])
    @user.roles << @role
    # Since user is not being updated here, we need to force the new role's policy update
    ComputedPolicy.update_user(@user)
    render nothing: true
  end

  def unassign_role
    @role = Role.find(params[:role])
    @user.roles.delete(@role)
    ComputedPolicy.update_user(@user)
    render nothing: true
  end

  private

  def user_params
    params.require(:user).permit(:is_active)
  end

  def can_edit?
    current_user.id != @user.try(:id)
  end

  def load_resource
    @user ||= User.find(params[:id])
  end

  def build_csv
    CSV.generate do |csv|
      csv << ["Full name", "Roles", "Last activity"]
      @users.each do |u|
        roles = u.roles.empty? ? nil : "#{u.roles.pluck(:name).join(",")}"
        csv << [u.full_name, roles, ApplicationController.helpers.last_activity(u)]
      end
    end
  end

  def apply_filters
    @users = @users.where("first_name LIKE ? OR last_name LIKE ? OR (email LIKE ? AND first_name IS NULL AND last_name IS NULL)", "%#{params["name"]}%", "%#{params["name"]}%", "%#{params["name"]}%") if params["name"].present?
    # There's no need to redo the join to roles_users because it was done by the scope "within"
    @users = @users.where("roles_users.role_id = ?", params["role"].to_i) if params["role"].present?
    @users = @users.where("last_sign_in_at > ? OR (last_sign_in_at IS NULL AND invitation_accepted_at IS NULL AND invitation_created_at > ?)", params["last_activity"], params["last_activity"]) if params["last_activity"].present?
  end

end
