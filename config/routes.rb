Rails.application.routes.draw do
  devise_for :users

  # Locale switching (requires authentication)
  post '/switch_locale', to: 'application#switch_locale', as: :switch_locale

  # Authenticated root paths (role-based routing)
  authenticated :user, ->(user) { user.admin_or_dispatcher? } do
    root to: "dashboard#index", as: :admin_root
  end

  authenticated :user, ->(user) { user.customer? } do
    root to: "customer/dashboard#show", as: :customer_root
  end

  # Fallback root for unauthenticated users
  root "dashboard#index"

  # Public offer submission (no authentication required)
  resources :offers, only: [ :show ] do
    member do
      post :submit_offer
    end
  end

  # Customer namespace (requires customer authentication)
  namespace :customer do
    resource :dashboard, only: [ :show ]

    resources :transport_requests do
      member do
        post :cancel
      end

      resource :quote, only: [] do
        post :accept
        post :decline
      end

      resources :carrier_requests, only: [] do
        member do
          post :accept
          post :reject
        end
      end
    end
  end

  # Admin namespace (requires admin authentication)
  namespace :admin do
    resources :carriers
    resources :pricing_rules

    resources :transport_requests do
      member do
        post :run_matching
        post :cancel
      end
    end

    resources :carrier_requests, only: [ :index, :show ] do
      member do
        post :accept
        post :reject
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
