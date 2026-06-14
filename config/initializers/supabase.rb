# frozen_string_literal: true

Rails.application.config.supabase.mode = :web

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
