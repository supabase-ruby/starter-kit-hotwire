class HomeController < ApplicationController
  # `/` (root) is publicly accessible — unauthenticated visitors see the
  # dashboard view without the auth chrome via `layouts/application`. The
  # `/dashboard` alias, however, is the authenticated entry point: the `unless`
  # guard re-enables `require_authentication` only when the request hits
  # `dashboard_path`, so a signed-out user landing there is redirected to
  # `new_session_path` by `request_authentication`.
  allow_unauthenticated_access only: :index, unless: -> { request.path == dashboard_path }

  def index
  end
end
