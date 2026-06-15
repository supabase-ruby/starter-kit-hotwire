# frozen_string_literal: true

require_relative "e2e_test_case"

# Single end-to-end smoke that exercises the registration → dashboard happy
# path against the real local Supabase stack started by `bin/e2e`. If this
# fails, the entire E2E pipeline (stack bootstrap, Capybara wiring,
# Supabase Auth, session cookie, dashboard routing) is broken.
class SmokeTest < E2ETestCase
  test "new sign-up lands on the dashboard" do
    email    = "smoke+#{SecureRandom.hex(4)}@example.test"
    password = "smoke-test-password-#{SecureRandom.hex(4)}"

    sign_up_as(email: email, password: password)

    assert_current_path root_path
    assert_selector "[data-test='dashboard']"
    assert_equal email, current_session_user.email
  end
end
