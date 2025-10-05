Rails.application.routes.draw do
  get "offers/show"
  get "offers/create"
  get "dashboard/index"
  devise_for :users

  # Root path
  root "dashboard#index"

  # Public offer submission (no authentication required)
  resources :offers, only: [:show] do
    member do
      post :submit_offer
    end
  end

  # Admin namespace (requires authentication)
  namespace :admin do
    get "carrier_requests/index"
    get "carrier_requests/show"
    get "carrier_requests/accept"
    get "carrier_requests/reject"
    get "transport_requests/index"
    get "transport_requests/show"
    get "transport_requests/new"
    get "transport_requests/create"
    get "transport_requests/edit"
    get "transport_requests/update"
    get "transport_requests/destroy"
    get "transport_requests/run_matching"
    get "transport_requests/cancel"
    get "carriers/index"
    get "carriers/show"
    get "carriers/new"
    get "carriers/create"
    get "carriers/edit"
    get "carriers/update"
    get "carriers/destroy"
    resources :carriers

    resources :transport_requests do
      member do
        post :run_matching
        post :cancel
      end
    end

    resources :carrier_requests, only: [:index, :show] do
      member do
        post :accept
        post :reject
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
