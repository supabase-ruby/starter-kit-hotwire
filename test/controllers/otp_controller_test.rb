# frozen_string_literal: true

require "test_helper"

class OtpControllerTest < ActionDispatch::IntegrationTest
  test "GET /otp/new renders the OTP request form" do
    get new_otp_path
    assert_response :success
    assert_select "form[data-test='otp-request-form']"
  end

  test "POST /otp triggers delivery and redirects to the verify form" do
    SupabaseAuthStubs.stub(:supabase_sign_in_with_otp, Supabase::Rails::Result.success(Object.new))

    post otp_index_path, params: { email: "alice@example.test" }

    assert_redirected_to verify_otp_index_path
    assert_equal I18n.t("supabase.rails.otp.sent"), flash[:notice]
    assert_equal "alice@example.test", SupabaseAuthStubs.calls[:supabase_sign_in_with_otp].first[:email]
  end

  test "GET /otp/verify renders the code-entry form" do
    get verify_otp_index_path, params: { email: "alice@example.test" }
    assert_response :success
    assert_select "form[data-test='otp-verify-form']"
  end

  test "POST /otp/verify with a valid token starts a session and redirects to dashboard" do
    fake_session = Object.new
    SupabaseAuthStubs.stub(:supabase_verify_otp, Supabase::Rails::Result.success(fake_session))

    post verify_otp_index_path, params: { email: "alice@example.test", token: "123456", type: "email" }

    assert_redirected_to root_url
    assert_equal I18n.t("supabase.rails.otp.verified"), flash[:notice]

    call = SupabaseAuthStubs.calls[:supabase_verify_otp].first
    assert_equal "123456", call[:token]
    assert_equal "email", call[:type]
    assert_equal "alice@example.test", call[:email]
  end

  test "POST /otp/verify with an invalid token re-renders the form with an alert" do
    error = Supabase::Rails::AuthError.new("Token has expired", Supabase::Rails::AuthError::AUTH_API_ERROR, 422)
    SupabaseAuthStubs.stub(:supabase_verify_otp, Supabase::Rails::Result.failure(error))

    post verify_otp_index_path, params: { email: "alice@example.test", token: "000000", type: "email" }

    assert_response :unprocessable_entity
    assert_select "[data-test='otp-verify-error']", text: /Token has expired/
  end
end
