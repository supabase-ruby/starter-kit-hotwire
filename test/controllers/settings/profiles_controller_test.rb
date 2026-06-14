# frozen_string_literal: true

require "test_helper"

class Settings::ProfilesControllerTest < ActionDispatch::IntegrationTest
  FakeUser = Data.define(:id, :email, :user_metadata)

  def stub_authenticated_user
    user = FakeUser.new(
      id: "user-uuid",
      email: "alice@example.test",
      user_metadata: { "display_name" => "Alice" }
    )
    SupabaseAuthStubs.stub(:resume_session_user) { user }
    user
  end

  test "PATCH /settings/profile calls supabase_update_user with display_name + email" do
    stub_authenticated_user
    SupabaseAuthStubs.stub(:supabase_update_user, Supabase::Rails::Result.success(Object.new))

    patch settings_profile_path, params: { display_name: "Alice Liddell", email: "alice@new.test" }

    assert_redirected_to settings_profile_path
    assert_equal "Profile updated.", flash[:notice]

    expected = { email: "alice@new.test", data: { "display_name" => "Alice Liddell" } }
    assert_equal expected, SupabaseAuthStubs.calls[:supabase_update_user].first
  end

  test "PATCH /settings/profile only sends display_name when email is blank" do
    stub_authenticated_user
    SupabaseAuthStubs.stub(:supabase_update_user, Supabase::Rails::Result.success(Object.new))

    patch settings_profile_path, params: { display_name: "Just A Name" }

    assert_redirected_to settings_profile_path
    expected = { data: { "display_name" => "Just A Name" } }
    assert_equal expected, SupabaseAuthStubs.calls[:supabase_update_user].first
  end

  test "PATCH /settings/profile when unauthenticated redirects to sign-in" do
    patch settings_profile_path, params: { display_name: "Alice" }

    assert_redirected_to new_session_path
    assert_empty SupabaseAuthStubs.calls[:supabase_update_user]
  end
end
