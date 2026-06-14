# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /session/new renders the sign-in form" do
    get new_session_path
    assert_response :success
    assert_select "form[data-test='login-form']"
    assert_select "input[data-test='login-email-input']"
  end

  test "POST /session with valid credentials starts a session and redirects to dashboard" do
    fake_session = Object.new
    SupabaseAuthStubs.stub(:authenticate_with_supabase, fake_session)

    post session_path, params: { email: "alice@example.test", password: "secret-pass" }

    assert_redirected_to root_url
    follow_redirect!
    assert_response :success

    call = SupabaseAuthStubs.calls[:authenticate_with_supabase].first
    assert_equal "alice@example.test", call[:email]
    assert_equal "secret-pass", call[:password]
    assert_equal [ fake_session ], SupabaseAuthStubs.calls[:start_new_session_for]
  end

  test "POST /session with invalid credentials re-renders the form with an alert" do
    SupabaseAuthStubs.stub(:authenticate_with_supabase, nil)

    post session_path, params: { email: "alice@example.test", password: "wrong" }

    assert_response :unauthorized
    assert_empty SupabaseAuthStubs.calls[:start_new_session_for]
    assert_select "[data-test='login-error']"
  end
end
