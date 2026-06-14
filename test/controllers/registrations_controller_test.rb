# frozen_string_literal: true

require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  AuthResponse = Struct.new(:user, :session, keyword_init: true)

  test "GET /registration/new renders the sign-up form" do
    get new_registration_path
    assert_response :success
    assert_select "form[data-test='register-form']"
  end

  test "POST /registration with auto-sign-in disabled redirects to sign-in with a confirmation notice" do
    response = AuthResponse.new(user: Object.new, session: nil)
    SupabaseAuthStubs.stub(:supabase_sign_up, Supabase::Rails::Result.success(response))

    post registration_path, params: { email: "new@example.test", password: "very-long-password" }

    assert_redirected_to new_session_path
    assert_equal I18n.t("supabase.rails.registrations.pending_confirmation"), flash[:notice]

    call = SupabaseAuthStubs.calls[:supabase_sign_up].first
    assert_equal "new@example.test", call[:email]
    assert_equal "very-long-password", call[:password]
    assert_empty SupabaseAuthStubs.calls[:start_new_session_for]
  end

  test "POST /registration with auto-sign-in enabled redirects to dashboard and starts session" do
    fake_session = Object.new
    response = AuthResponse.new(user: Object.new, session: fake_session)
    SupabaseAuthStubs.stub(:supabase_sign_up, Supabase::Rails::Result.success(response))

    post registration_path, params: { email: "new@example.test", password: "very-long-password" }

    assert_redirected_to root_url
    assert_equal I18n.t("supabase.rails.registrations.created"), flash[:notice]
  end

  test "POST /registration with weak password re-renders the form with an error" do
    error = Supabase::Rails::AuthError.new("Password is too short", Supabase::Rails::AuthError::WEAK_PASSWORD, 422)
    SupabaseAuthStubs.stub(:supabase_sign_up, Supabase::Rails::Result.failure(error))

    post registration_path, params: { email: "new@example.test", password: "short" }

    assert_response :unprocessable_entity
    assert_select "[data-test='register-error']", text: /Password is too short/
  end
end
