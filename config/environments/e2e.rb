# The e2e environment is used by `bin/e2e` to run the test suite against a
# real local Supabase stack (started via the Supabase CLI). It inherits every
# setting from the test environment so fixtures, mailer stubs, and forgery
# protection behave identically; the only divergence is log verbosity, which
# is bumped to INFO so HTTP exchanges with Supabase are visible during runs.

require_relative "test"

Rails.application.configure do
  config.log_level = :info
end
