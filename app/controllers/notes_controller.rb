class NotesController < ApplicationController
  NOT_FOUND_MESSAGE = "Note not found".freeze

  def index
    response = current_supabase_client.from("notes").select("id,content,created_at").execute
    @notes = response.data || []
  end

  def update
    response = current_supabase_client
      .from("notes")
      .update({ content: params.expect(note: [ :content ])[:content] })
      .eq("id", params[:id])
      .execute

    if Array(response.data).empty?
      redirect_to notes_path, alert: NOT_FOUND_MESSAGE
    else
      redirect_to notes_path, notice: "Note updated"
    end
  end

  def destroy
    response = current_supabase_client
      .from("notes")
      .delete
      .eq("id", params[:id])
      .execute

    if Array(response.data).empty?
      redirect_to notes_path, alert: NOT_FOUND_MESSAGE
    else
      redirect_to notes_path, notice: "Note deleted"
    end
  end

  private

  # Per-request `Supabase::Client` whose Authorization header carries the
  # current user's access token (overlaid by the gem's web-mode middleware
  # in `Web::CookieCredentialStrategy#user_context`). Every PostgREST call
  # made through this client is RLS-scoped to `Current.user` — that's the
  # invariant the e2e tests for this controller exercise.
  def current_supabase_client
    request.env[Supabase::Rails::CONTEXT_KEY].supabase
  end
end
