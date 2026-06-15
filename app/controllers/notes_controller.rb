class NotesController < ApplicationController
  def index
    response = current_supabase_client.from("notes").select("id,content,created_at").execute
    @notes = response.data || []
  end

  private

  # Per-request `Supabase::Client` whose Authorization header carries the
  # current user's access token (overlaid by the gem's web-mode middleware
  # in `Web::CookieCredentialStrategy#user_context`). Every PostgREST call
  # made through this client is RLS-scoped to `Current.user` — that's the
  # invariant the e2e test for this controller exercises.
  def current_supabase_client
    request.env[Supabase::Rails::CONTEXT_KEY].supabase
  end
end
