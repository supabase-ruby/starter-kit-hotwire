# frozen_string_literal: true

require "active_support/test_case"
require_relative "supabase_reset"

# Shared base class for end-to-end tests that exercise the real local Supabase
# stack started by `bin/e2e`. Each test starts from a clean slate: Supabase
# Auth users are deleted and any tables registered with `SupabaseReset.tables=`
# are truncated.
class E2ETestCase < ActiveSupport::TestCase
  setup do
    SupabaseReset.clean!
  end
end
