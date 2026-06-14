ENV["RAILS_ENV"] ||= "test"
ENV["SUPABASE_URL"] ||= "https://test.supabase.invalid"
ENV["SUPABASE_PUBLISHABLE_KEY"] ||= "sb_publishable_test"
ENV["SUPABASE_SECRET_KEY"] ||= "sb_secret_test"

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/supabase_auth_stubs"

ApplicationController.prepend(SupabaseAuthStubs)

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    fixtures :all

    setup do
      SupabaseAuthStubs.reset!
      ::Current.user = nil
      ::Current.session = nil
    end

    teardown do
      SupabaseAuthStubs.reset!
      ::Current.user = nil
      ::Current.session = nil
    end
  end
end
