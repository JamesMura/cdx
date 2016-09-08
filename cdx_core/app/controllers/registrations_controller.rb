class RegistrationsController < Devise::RegistrationsController

  before_action :authenticate_user!
  before_filter :load_locales
  skip_before_filter :ensure_context, except: :edit

  protected

  # Do not require current password for update, since a user registered via Omniauth has an unknown random password assigned
  # TODO: Remove required password validation for users signed up via Omniauth, and do require current password here
  # resource here is a: User
  def update_resource(resource, params)
    # Do not update password if nothing is entered
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation)
    else
      # Avoid security issue when password can be updated by not sending password confirmation
      params[:password_confirmation] ||= ""
    end
    # Update the resource as usual
    # update with password does a cleanup internally.  Returns boolean
    if resource.update_with_password(params) 
      ## automatically re-sign-in the user
      sign_in resource, bypass: true
      flash[:notice] = I18n.t('password_changed')
    end
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end

  private

  def load_locales
    @locales ||= [%w(English en)]
  end

  def sign_up_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end

  def account_update_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :current_password,
      :email,
      :telephone,
      :password,
      :password_confirmation,
      :locale,
      :time_zone,
      :timestamps_in_device_time_zone
    )
  end
end
