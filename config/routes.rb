Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Main pages
  root "checks#show"                                # The hero checker
  get "/precos", to: "precos#index"               # Today's CEASA index
  get "/produtos/:id", to: "products#show", as: :product  # Product detail
  get "/sobre", to: "pages#sobre"                 # About page
end
