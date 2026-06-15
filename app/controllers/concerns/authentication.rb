# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  SESSION_EXPIRED_FLASH = "Your session has expired"

  # `prepend`ed so it wins method lookup over `Supabase::Rails::Authentication`
  # (which `included do ... include` mixes in below this concern). The override
  # `super`s into the gem's redirect/store-location behavior unchanged — it
  # only attaches a flash when the request arrived with an `sb-session` cookie
  # the middleware just had to invalidate (expired token whose refresh failed,
  # tampered ciphertext, etc.). Without the prepend the method resolution
  # order is [Klass, Supabase::Rails::Authentication, Authentication, ...] —
  # the gem's `request_authentication` wins and the flash is never set.
  module ExpiredSessionFlash
    def request_authentication
      if request.cookies[Supabase::Rails::SessionStore::DEFAULT_COOKIE_NAME].present?
        flash[:alert] = SESSION_EXPIRED_FLASH
      end
      super
    end
  end

  included do
    include Supabase::Rails::Authentication
    prepend ExpiredSessionFlash
  end
end
