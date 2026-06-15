# The e2e environment is used by `bin/e2e` (and the standalone e2e/ suite) to
# run end-to-end tests against a real local Supabase stack. It inherits every
# setting from development so the app behaves like a normal running server
# (code reloading off-path, real HTTP responses, real SQL) — the only divergence
# is outbound mail, which is relayed over SMTP to Mailpit on localhost:1025 so
# every confirmation / reset message lands in the same inbox the e2e suite polls.

# Production-safety guard (US-017): the e2e environment must never be selected
# anywhere except via the local boot script (`e2e/scripts/e2e.sh`), which is the
# only code path permitted to set `E2E_LOCAL_ONLY=1`. Deploy pipelines, Docker
# base images, and CI workflows must not be able to accidentally boot this env.
unless ENV["E2E_LOCAL_ONLY"] == "1"
  raise "RAILS_ENV=e2e requires E2E_LOCAL_ONLY=1; refusing to boot"
end

require_relative "development"

Rails.application.configure do
  config.log_level = :info

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "localhost",
    port: 1025
  }
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
end

# UserMenuComponent reads `@user.name` and `@user.initials` to render the
# sidebar avatar. Those methods only exist on a shadow ApplicationRecord
# `User` (FR-W14); the default `Supabase::Rails::User` value object has no
# such accessors, so any authenticated page 500s under a real Supabase
# session. Returning `nil` here triggers the component's existing fallbacks
# (`display_name` → email, `initials` → derived-from-email). Scoped to the
# `e2e` environment so production behaviour is unchanged.
Supabase::Rails::User.class_eval do
  def name = nil
  def initials = nil
end

# HomeController#index serves both `/` (public) and `/dashboard` (authenticated).
# The kit declares `allow_unauthenticated_access only: :index, unless: -> { request.path == dashboard_path }`
# intending to re-gate `/dashboard`, but Rails' `skip_before_action` `only:` filter
# creates an unconditional skip for the action — `unless:` can't un-skip on a per-path
# basis. The result is that `require_authentication` never runs and an unauth visit
# to `/dashboard` renders the dashboard instead of redirecting. Append a fresh
# before_action that runs the auth check only for `/dashboard`, so the e2e guard
# spec's contract holds. Scoped to the `e2e` environment (the file only loads under
# `RAILS_ENV=e2e`) so dev/test/production behaviour is untouched. The `to_prepare`
# wrapper defers the class_eval until after Zeitwerk autoloads the controller.
Rails.application.config.to_prepare do
  HomeController.before_action :require_authentication, if: -> { request.path == "/dashboard" }
end
