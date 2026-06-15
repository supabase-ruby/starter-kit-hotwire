# frozen_string_literal: true

require "test_helper"

# Unit-level coverage of the `Authentication::ExpiredSessionFlash` override
# prepended into `ApplicationController`. The E2E flow proves the end-to-end
# happy path against a real Supabase stack, but it only runs when Docker +
# the local stack are up; this test fences the flash-assignment logic against
# pure Rails so a regression to the include/prepend chain (which silently
# stops calling our override) fails the regular `bin/rails test` suite.
class SessionExpiryTest < ActionDispatch::IntegrationTest
  test "authenticated request with stale sb-session cookie redirects to sign-in with the expired flash" do
    cookies[Supabase::Rails::SessionStore::DEFAULT_COOKIE_NAME] = "anything-the-middleware-cant-decrypt"

    get settings_profile_path

    assert_redirected_to new_session_path
    assert_equal Authentication::SESSION_EXPIRED_FLASH, flash[:alert]
  end

  test "authenticated request with no sb-session cookie redirects without the expired flash" do
    get settings_profile_path

    assert_redirected_to new_session_path
    assert_nil flash[:alert]
  end
end
