Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # OAuth2 authentication routes with Authlift8
  # Security: State token validation, secure session handling
  scope :auth, as: :auth do
    # GET /auth/login - Initiate OAuth login flow
    get 'login', to: 'sessions#new'

    # GET /auth/callback - OAuth callback handler (receives code and state)
    get 'callback', to: 'sessions#create'

    # POST /auth/logout - Logout and clear session
    post 'logout', to: 'sessions#destroy'

    # DELETE /auth/logout - Alternative logout route (RESTful)
    delete 'logout', to: 'sessions#destroy'
  end

  # Convenience route for logout (common user expectation)
  get 'logout', to: 'sessions#destroy'

  # API v1 Routes
  # RESTful API endpoints for external systems (M23, Shopify3, Bizcart)
  # Authentication: Bearer token (Company.api_token)
  namespace :api do
    namespace :v1 do
      # Products API
      # - GET /api/v1/products - List active, sellable products
      # - GET /api/v1/products/:sku - Show product details
      # - PATCH /api/v1/products/:sku - Update product
      resources :products, only: [:index, :show, :update], param: :sku

      # Inventories API
      # - POST /api/v1/inventories/update - Update product inventory
      post 'inventories/update', to: 'inventories#update_inventory'

      # Sync Tasks API
      # - POST /api/v1/sync_tasks - Receive sync task from external system
      resources :sync_tasks, only: [:create]
    end
  end

  # Authenticated routes
  # Require user authentication for all routes below
  # Dashboard, products, storages, attributes, labels, catalogs
  root 'dashboard#index'

  # Company switching (for users with multiple companies)
  post 'switch_company/:id', to: 'companies#switch', as: :switch_company

  # Global search
  get 'search', to: 'search#index', as: :search

  # Resource routes
  resources :products do
    member do
      post :duplicate
    end
    collection do
      post :bulk_destroy
      post :bulk_update_labels
      get :validate_sku
    end
  end

  resources :storages
  resources :product_attributes
  resources :labels
  resources :catalogs
end
