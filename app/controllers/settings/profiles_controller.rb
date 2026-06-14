class Settings::ProfilesController < ApplicationController
  before_action :set_user

  def show
  end

  def update
    result = supabase_update_user(user_attributes)
    if result.success?
      redirect_to settings_profile_path, notice: "Profile updated."
    else
      @update_error = result.error&.message
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    # TODO(US-009): wire account deletion through the Supabase admin client.
    redirect_to settings_profile_path, alert: "Account deletion is not yet supported."
  end

  private
    def set_user
      @user = Current.user
    end

    def user_attributes
      attrs = {}
      attrs[:email] = params[:email] if params[:email].present?
      data = {}
      data["name"] = params[:name] if params[:name].present?
      attrs[:data] = data unless data.empty?
      attrs
    end
end
