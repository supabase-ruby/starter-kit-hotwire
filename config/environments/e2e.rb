# The e2e environment is used by `bin/e2e` (and the standalone e2e/ suite) to
# run end-to-end tests against a real local Supabase stack. It inherits every
# setting from development so the app behaves like a normal running server
# (code reloading off-path, real HTTP responses, real SQL) — the only divergence
# is outbound mail, which is relayed over SMTP to Mailpit on localhost:1025 so
# every confirmation / reset message lands in the same inbox the e2e suite polls.

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
