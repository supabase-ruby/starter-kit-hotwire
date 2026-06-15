# frozen_string_literal: true

require "test_helper"
require "ostruct"
require_relative "supabase_reset"

class SupabaseResetTest < ActiveSupport::TestCase
  # Records calls so each test can both drive `clean!` and assert what was
  # invoked on the admin client without pulling in a mocking gem.
  class FakeAdmin
    attr_reader :list_calls, :deleted_ids

    def initialize(pages: [], &on_list)
      @pages = pages
      @on_list = on_list
      @list_calls = []
      @deleted_ids = []
    end

    def list_users(page:, per_page:)
      @list_calls << { page: page, per_page: per_page }
      return @on_list.call if @on_list

      @pages.shift || []
    end

    def delete_user(id)
      @deleted_ids << id
    end
  end

  setup do
    SupabaseReset.tables = []
    SupabaseReset.admin = nil
  end

  teardown do
    SupabaseReset.tables = []
    SupabaseReset.admin = nil
  end

  test "clean! deletes every user across pages via the admin API" do
    users = [
      OpenStruct.new(id: "00000000-0000-0000-0000-aaaaaaaaaaaa"),
      OpenStruct.new(id: "00000000-0000-0000-0000-bbbbbbbbbbbb")
    ]
    fake = FakeAdmin.new(pages: [ users, [] ])
    SupabaseReset.admin = fake

    SupabaseReset.clean!

    assert_equal users.map(&:id), fake.deleted_ids
    assert_equal [
      { page: 1, per_page: SupabaseReset::USER_PAGE_SIZE },
      { page: 1, per_page: SupabaseReset::USER_PAGE_SIZE }
    ], fake.list_calls
  end

  test "clean! re-pages page 1 until list_users returns empty" do
    page_one = Array.new(SupabaseReset::USER_PAGE_SIZE) do |i|
      OpenStruct.new(id: format("00000000-0000-0000-0000-%012d", i))
    end
    page_two = [ OpenStruct.new(id: "00000000-0000-0000-0000-cccccccccccc") ]
    fake = FakeAdmin.new(pages: [ page_one, page_two, [] ])
    SupabaseReset.admin = fake

    SupabaseReset.clean!

    assert_equal page_one.map(&:id) + page_two.map(&:id), fake.deleted_ids
    assert_equal 3, fake.list_calls.size
  end

  test "clean! raises Unreachable when the auth API connection fails" do
    fake = FakeAdmin.new { raise Faraday::ConnectionFailed, "connection refused" }
    SupabaseReset.admin = fake

    error = assert_raises(SupabaseReset::Unreachable) { SupabaseReset.clean! }
    assert_match(/Supabase stack unreachable/, error.message)
    assert_match(/connection refused/, error.message)
  end

  test "clean! raises Unreachable on AuthRetryableError (network/5xx)" do
    fake = FakeAdmin.new do
      raise ::Supabase::Auth::Errors::AuthRetryableError.new("upstream timeout", status: 504)
    end
    SupabaseReset.admin = fake

    assert_raises(SupabaseReset::Unreachable) { SupabaseReset.clean! }
  end

  test "clean! truncates every configured ActiveRecord table" do
    conn = ActiveRecord::Base.connection
    conn.execute("CREATE TABLE supabase_reset_fixture (id INTEGER PRIMARY KEY)")
    conn.execute("INSERT INTO supabase_reset_fixture (id) VALUES (1), (2), (3)")
    SupabaseReset.tables = [ "supabase_reset_fixture" ]
    SupabaseReset.admin = FakeAdmin.new(pages: [ [] ])

    SupabaseReset.clean!

    count = conn.select_value("SELECT COUNT(*) FROM supabase_reset_fixture")
    assert_equal 0, count
  ensure
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS supabase_reset_fixture")
  end

  test "clean! raises descriptive Error when SUPABASE_URL is missing" do
    SupabaseReset.admin = nil
    with_env("SUPABASE_URL" => nil) do
      error = assert_raises(SupabaseReset::Error) { SupabaseReset.clean! }
      assert_match(/SUPABASE_URL is not set/, error.message)
    end
  end

  test "clean! raises descriptive Error when SUPABASE_SERVICE_ROLE_KEY is missing" do
    SupabaseReset.admin = nil
    with_env("SUPABASE_SERVICE_ROLE_KEY" => nil) do
      error = assert_raises(SupabaseReset::Error) { SupabaseReset.clean! }
      assert_match(/SUPABASE_SERVICE_ROLE_KEY is not set/, error.message)
    end
  end

  private

  def with_env(overrides)
    previous = overrides.transform_values { |_| nil }
    overrides.each_key { |k| previous[k] = ENV[k] }
    overrides.each { |k, v| ENV[k] = v }
    yield
  ensure
    previous.each { |k, v| ENV[k] = v }
  end
end
