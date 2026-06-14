# frozen_string_literal: true

# Test-only stubs for the gem's auth helpers + session bookkeeping. Prepended
# into ApplicationController so every controller that exercises a supabase_*
# helper consults the test's thread-local config first. Tests set return
# values via `SupabaseAuthStubs.stub(...)` and inspect recorded calls via
# `SupabaseAuthStubs.calls`.
module SupabaseAuthStubs
  @stubs = {}
  @calls = Hash.new { |h, k| h[k] = [] }
  @mutex = Mutex.new

  class << self
    attr_reader :mutex

    def stubs
      @stubs
    end

    def calls
      @calls
    end

    def stub(method, value = nil, &block)
      @mutex.synchronize { @stubs[method] = block || ->(*) { value } }
    end

    def reset!
      @mutex.synchronize do
        @stubs = {}
        @calls = Hash.new { |h, k| h[k] = [] }
      end
    end

    def record(method, payload)
      @mutex.synchronize { @calls[method] << payload }
    end

    def stubbed?(method)
      @mutex.synchronize { @stubs.key?(method) }
    end

    def fetch(method, *args, **kwargs)
      stub = @mutex.synchronize { @stubs[method] }
      stub.call(*args, **kwargs)
    end
  end

  def authenticate_with_supabase(email:, password:)
    SupabaseAuthStubs.record(:authenticate_with_supabase, { email: email, password: password })
    return super unless SupabaseAuthStubs.stubbed?(:authenticate_with_supabase)

    SupabaseAuthStubs.fetch(:authenticate_with_supabase, email: email, password: password)
  end

  def supabase_sign_up(email:, password:, **opts)
    SupabaseAuthStubs.record(:supabase_sign_up, { email: email, password: password, opts: opts })
    return super unless SupabaseAuthStubs.stubbed?(:supabase_sign_up)

    SupabaseAuthStubs.fetch(:supabase_sign_up, email: email, password: password, **opts)
  end

  def supabase_reset_password(email:, **opts)
    SupabaseAuthStubs.record(:supabase_reset_password, { email: email, opts: opts })
    return super unless SupabaseAuthStubs.stubbed?(:supabase_reset_password)

    SupabaseAuthStubs.fetch(:supabase_reset_password, email: email, **opts)
  end

  def supabase_update_user(attributes)
    SupabaseAuthStubs.record(:supabase_update_user, attributes)
    return super unless SupabaseAuthStubs.stubbed?(:supabase_update_user)

    SupabaseAuthStubs.fetch(:supabase_update_user, attributes)
  end

  def supabase_sign_in_with_otp(email: nil, phone: nil, **opts)
    SupabaseAuthStubs.record(:supabase_sign_in_with_otp, { email: email, phone: phone, opts: opts })
    return super unless SupabaseAuthStubs.stubbed?(:supabase_sign_in_with_otp)

    SupabaseAuthStubs.fetch(:supabase_sign_in_with_otp, email: email, phone: phone, **opts)
  end

  def supabase_verify_otp(token:, type:, email: nil, phone: nil)
    SupabaseAuthStubs.record(
      :supabase_verify_otp,
      { token: token, type: type, email: email, phone: phone }
    )
    return super unless SupabaseAuthStubs.stubbed?(:supabase_verify_otp)

    SupabaseAuthStubs.fetch(:supabase_verify_otp, token: token, type: type, email: email, phone: phone)
  end

  def supabase_exchange_code_for_session(code:, state: nil, redirect_to: nil)
    SupabaseAuthStubs.record(
      :supabase_exchange_code_for_session,
      { code: code, state: state, redirect_to: redirect_to }
    )
    return super unless SupabaseAuthStubs.stubbed?(:supabase_exchange_code_for_session)

    SupabaseAuthStubs.fetch(
      :supabase_exchange_code_for_session,
      code: code, state: state, redirect_to: redirect_to
    )
  end

  def supabase_sign_in_with_oauth(provider:, redirect_to:, scopes: nil)
    SupabaseAuthStubs.record(
      :supabase_sign_in_with_oauth,
      { provider: provider, redirect_to: redirect_to, scopes: scopes }
    )
    return super unless SupabaseAuthStubs.stubbed?(:supabase_sign_in_with_oauth)

    SupabaseAuthStubs.fetch(
      :supabase_sign_in_with_oauth,
      provider: provider, redirect_to: redirect_to, scopes: scopes
    )
  end

  def start_new_session_for(supabase_session)
    SupabaseAuthStubs.record(:start_new_session_for, supabase_session)
    user = SupabaseAuthStubs.stubs[:start_new_session_user]&.call(supabase_session)
    ::Current.user = user if user
    ::Current.session = supabase_session
    supabase_session
  end

  def terminate_session(scope: :local)
    SupabaseAuthStubs.record(:terminate_session, scope)
    ::Current.user = nil
    ::Current.session = nil
  end

  def resume_session
    user = SupabaseAuthStubs.stubs[:resume_session_user]&.call
    if user
      ::Current.user = user
      ::Current.session = SupabaseAuthStubs.stubs[:resume_session_session]&.call
      true
    else
      super
    end
  end

  def populate_current_attributes
    return if SupabaseAuthStubs.stubs.key?(:resume_session_user)

    super
  end
end
