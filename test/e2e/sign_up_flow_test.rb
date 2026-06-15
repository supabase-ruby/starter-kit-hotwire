# frozen_string_literal: true

require_relative "e2e_test_case"
require_relative "../support/supabase_reset"

# End-to-end coverage of the email + password sign-up flow against the real
# local Supabase stack. Covers the happy path (redirect to the dashboard +
# user persisted in Supabase Auth) and the two validation negatives (invalid
# email, weak password) — both of which must surface an inline error and
# leave Supabase Auth untouched.
class SignUpFlowTest < E2ETestCase
  test "valid sign-up lands on the dashboard and creates a Supabase Auth user" do
    email    = "signup+#{SecureRandom.hex(4)}@example.test"
    password = "signup-test-password-#{SecureRandom.hex(4)}"

    sign_up_as(email: email, password: password)

    assert_current_path root_path
    assert_selector "[data-test='dashboard']"
    assert_equal email, current_session_user.email

    assert_includes admin_user_emails, email,
                    "Expected #{email} to exist in Supabase Auth after sign-up"
  end

  test "invalid email shows inline error and does not create a user" do
    invalid_email = "not-a-valid-email"
    password      = "signup-test-password-#{SecureRandom.hex(4)}"

    visit new_registration_path
    assert_selector "form[data-test='register-form']"

    # The form uses `<input type=email required>`; disable HTML5 validation so
    # the bad value reaches the server, which is what this test is exercising.
    page.execute_script(
      "document.querySelector(\"form[data-test='register-form']\").setAttribute('novalidate', '')"
    )

    fill_in "email", with: invalid_email
    fill_in "password", with: password
    click_button "Create account"

    assert_selector "[data-test='register-error']"
    assert_selector "form[data-test='register-form']"
    assert_empty admin_user_emails.grep(/#{Regexp.escape(invalid_email)}/i)
  end

  test "weak password shows inline error and does not create a user" do
    email         = "weakpw+#{SecureRandom.hex(4)}@example.test"
    weak_password = "abc12" # under Supabase's default 6-char minimum

    visit new_registration_path
    assert_selector "form[data-test='register-form']"

    fill_in "email", with: email
    fill_in "password", with: weak_password
    click_button "Create account"

    assert_selector "[data-test='register-error']"
    assert_selector "form[data-test='register-form']"
    assert_not_includes admin_user_emails, email
  end

  private

  def admin_user_emails
    SupabaseReset.admin.list_users(page: 1, per_page: 200).map(&:email)
  end
end
