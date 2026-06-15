# frozen_string_literal: true

class SessionsController < Supabase::Rails::SessionsController
  layout "auth", only: :new

  # Override the gem's destroy (which redirects to `root_path`) so a signed-out
  # user lands on the explicit public landing page with log-in / register CTAs
  # instead of the bare dashboard shell. `terminate_session` clears the
  # encrypted session cookie + `Current` before the redirect.
  def destroy
    terminate_session
    redirect_to welcome_path,
                notice: I18n.t("supabase.rails.sessions.destroyed")
  end
end
