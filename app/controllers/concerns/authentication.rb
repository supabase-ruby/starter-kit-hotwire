# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    include Supabase::Rails::Authentication
  end
end
