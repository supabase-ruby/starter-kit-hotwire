# frozen_string_literal: true

require "supabase-auth"

# Wipes the local Supabase stack between E2E tests so each one starts from a
# known state:
#
#   1. Deletes every Supabase Auth user via `/auth/v1/admin/users` (admin API,
#      authenticated with the service role key).
#   2. Truncates the ActiveRecord tables registered via `SupabaseReset.tables=`
#      so RLS-governed app data also returns to a clean slate.
#
# Configuration (run once, e.g. in `test_helper.rb` or per-suite):
#
#   SupabaseReset.tables = %w[posts comments]
#
# Usage:
#
#   class FooFlowTest < E2ETestCase
#     test "…" do
#       # SupabaseReset.clean! has already been invoked in setup.
#     end
#   end
#
module SupabaseReset
  Error = Class.new(StandardError)
  Unreachable = Class.new(Error)

  USER_PAGE_SIZE = 200
  ADMIN_TIMEOUT_SECONDS = 5

  class << self
    attr_writer :tables, :admin

    def tables
      @tables ||= []
    end

    def admin
      @admin ||= build_admin
    end

    def clean!
      delete_all_users!
      truncate_tables!
    end

    private

    def build_admin
      url = require_env!("SUPABASE_URL")
      key = require_env!("SUPABASE_SERVICE_ROLE_KEY")

      ::Supabase::Auth::AdminApi.new(
        url: "#{url.chomp('/')}/auth/v1",
        headers: { "apikey" => key, "Authorization" => "Bearer #{key}" },
        timeout: ADMIN_TIMEOUT_SECONDS
      )
    end

    def require_env!(name)
      value = ENV[name]
      raise Error, "#{name} is not set; cannot reset Supabase Auth." if value.nil? || value.empty?

      value
    end

    def delete_all_users!
      loop do
        users = admin.list_users(page: 1, per_page: USER_PAGE_SIZE)
        break if users.empty?

        users.each { |user| admin.delete_user(user.id) }
      end
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError,
           ::Supabase::Auth::Errors::AuthRetryableError => e
      raise Unreachable,
            "Supabase stack unreachable at #{ENV['SUPABASE_URL'].inspect}: #{e.class} #{e.message}"
    end

    def truncate_tables!
      return if tables.empty?

      conn = ActiveRecord::Base.connection
      tables.each do |table|
        conn.execute("DELETE FROM #{conn.quote_table_name(table)}")
      end
    end
  end
end
