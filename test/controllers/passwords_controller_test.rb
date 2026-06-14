# frozen_string_literal: true

require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "GET /passwords/new renders the reset request form" do
    get new_password_path
    assert_response :success
    assert_select "form[data-test='password-reset-form']"
  end

  test "POST /passwords sends a reset email and redirects to sign-in" do
    SupabaseAuthStubs.stub(:supabase_reset_password, Supabase::Rails::Result.success(nil))

    post passwords_path, params: { email: "alice@example.test" }

    assert_redirected_to new_session_path
    assert_equal I18n.t("supabase.rails.passwords.reset_sent"), flash[:notice]
    assert_equal "alice@example.test", SupabaseAuthStubs.calls[:supabase_reset_password].first[:email]
  end

  test "GET /passwords/:token/edit renders the new-password form" do
    get edit_password_path(token: "recovery-token")
    assert_response :success
    assert_select "form[data-test='password-update-form']"
  end

  test "PUT /passwords/:token updates the password and redirects to sign-in" do
    SupabaseAuthStubs.stub(:supabase_update_user, Supabase::Rails::Result.success(Object.new))

    put password_path(token: "recovery-token"), params: { password: "new-strong-password" }

    assert_redirected_to new_session_path
    assert_equal I18n.t("supabase.rails.passwords.updated"), flash[:notice]
    assert_equal({ password: "new-strong-password" }, SupabaseAuthStubs.calls[:supabase_update_user].first)
  end

  test "PUT /passwords/:token surfaces a failure as a flash alert" do
    error = Supabase::Rails::AuthError.session_missing
    SupabaseAuthStubs.stub(:supabase_update_user, Supabase::Rails::Result.failure(error))

    put password_path(token: "recovery-token"), params: { password: "new-strong-password" }

    assert_response :unprocessable_entity
    assert_select "[data-test='password-update-error']", text: /Authentication required/
  end
end
