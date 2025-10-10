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

  # Defines the root path route ("/")
  # root "posts#index"
end
