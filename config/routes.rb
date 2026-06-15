Rails.application.routes.draw do
  supabase_authentication_routes

  get "sign_in", to: redirect("/session/new"), as: :sign_in
  get "sign_up", to: redirect("/registration/new"), as: :sign_up

  get "welcome",   to: "pages#welcome", as: :welcome
  get "dashboard", to: "home#index",    as: :dashboard

  resources :notes, only: %i[index update destroy]

  namespace :settings do
    resource :profile,    only: %i[show update destroy], controller: "profiles"
    resource :appearance, only: %i[show],                controller: "appearances"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
