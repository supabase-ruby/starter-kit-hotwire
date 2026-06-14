class PagesController < ApplicationController
  allow_unauthenticated_access only: :welcome

  def welcome
  end
end
