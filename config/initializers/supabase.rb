# frozen_string_literal: true

Rails.application.config.supabase.mode = :web

# Supabase credentials come from env vars (see .env.example). The gem reads
# `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `SUPABASE_SECRET_KEY` itself
# during boot; nothing to do here for development/test/production.
#
# In the e2e environment we additionally fall back to the local stack defaults
# emitted by `supabase status --output env`, so `bin/rails console -e e2e`
# works even when the caller didn't go through `bin/e2e` (which would have
# already populated these). Missing keys are filled in; values already set in
# the shell are preserved.
if Rails.env.e2e?
  required = {
    "SUPABASE_URL" => "API_URL",
    "SUPABASE_ANON_KEY" => "ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY" => "SERVICE_ROLE_KEY"
  }

  if required.keys.any? { |k| ENV[k].nil? || ENV[k].empty? }
    require "open3"
    begin
      out, _err, status = Open3.capture3("supabase", "status", "--output", "env")
      if status.success?
        defaults = out.each_line.with_object({}) do |line, acc|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?("#")
          key, _, value = stripped.partition("=")
          acc[key] = value.gsub(/\A"|"\z/, "")
        end
        required.each do |env_name, status_key|
          next if ENV[env_name] && !ENV[env_name].empty?
          ENV[env_name] = defaults[status_key] if defaults[status_key]
        end
      end
    rescue Errno::ENOENT
      # Supabase CLI not installed — leave env vars as-is so the gem's own
      # missing-config error fires with its actionable message.
    end
  end
end

# Origins the OAuth + password-reset helpers will accept as redirect targets.
# Path-only redirects are always allowed; absolute URLs must match an entry
# below. Defaults to [request.host] at runtime when this list is empty.
# Rails.application.config.supabase.allowed_redirect_origins = ["https://example.com"]

# Expose `current_user` as a view helper. nil = derive from mode
# (true in :web, false in :api).
# Rails.application.config.supabase.expose_current_user = nil

# Encrypted session cookie defaults. `secure: nil` = auto-detect from Rails.env.
# Rails.application.config.supabase.session = {
#   cookie_name: "sb-session",
#   same_site:   :lax,
#   secure:      nil,
#   domain:      nil,
#   path:        "/"
# }
