Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Test-only authentication backdoor for system tests
  # SECURITY: Only available in test environment
  if Rails.env.test?
    get "test_login", to: "test_sessions#create"
    post "test_login", to: "test_sessions#create"
    delete "test_logout", to: "test_sessions#destroy"
  end

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
    get "login", to: "sessions#new"

    # GET /auth/callback - OAuth callback handler (receives code and state)
    get "callback", to: "sessions#create"

    # POST /auth/logout - Logout and clear session
    post "logout", to: "sessions#destroy"

    # DELETE /auth/logout - Alternative logout route (RESTful)
    delete "logout", to: "sessions#destroy"
  end

  # SECURITY: GET logout removed - use POST/DELETE only to prevent CSRF
  # GET requests can be prefetched by browsers, cached, or triggered via image tags
  # This prevents authentication bypass attacks
  # get 'logout', to: 'sessions#destroy'  # REMOVED - SECURITY VULNERABILITY

  # API v1 Routes
  # RESTful API endpoints for external systems (M23, Shopify3, Bizcart)
  # Authentication: Bearer token (Company.api_token)
  namespace :api do
    namespace :v1 do
      # Health checks (no authentication required)
      get "health", to: "health#show"
      get "health/ready", to: "health#ready"

      # Products API
      # - GET /api/v1/products - List active, sellable products
      # - GET /api/v1/products/:sku - Show product details
      # - PATCH /api/v1/products/:sku - Update product
      resources :products, only: [ :index, :show, :update ], param: :sku

      # Inventories API
      # - POST /api/v1/inventories/update - Update product inventory
      post "inventories/update", to: "inventories#update_inventory"

      # Sync Tasks API
      # - POST /api/v1/sync_tasks - Receive sync task from external system
      resources :sync_tasks, only: [ :create ]
    end
  end

  # Authenticated routes
  # Require user authentication for all routes below
  # Dashboard, products, storages, attributes, labels, catalogs
  root "dashboard#index"

  # Company switching (for users with multiple companies)
  post "switch_company/:id", to: "companies#switch", as: :switch_company

  # Global search
  get "search", to: "search#index", as: :search
  get "search/recent", to: "search#recent", as: :search_recent

  # Resource routes
  # Bulk operations for products (extracted from ProductsController for SRP)
  scope :products do
    scope :bulk, controller: :product_bulk_operations do
      post :destroy, action: :destroy, as: :products_bulk_destroy
      post :update_labels, action: :update_labels, as: :products_bulk_update_labels
      get :labels_for_products, action: :labels_for_products, as: :products_bulk_labels_for_products
    end
  end

  resources :products do
    member do
      post :duplicate
      patch :toggle_active
      get :attribute_value
    end
    collection do
      get :validate_sku
    end

    # Nested resources for product detail page
    resources :labels, controller: :product_labels, only: [ :create, :destroy ]
    resources :catalogs, controller: :product_catalogs, only: [ :create, :destroy ]
    resources :images, only: [ :create, :update, :destroy ], controller: "product_images" do
      collection do
        patch :reorder         # Reorder images via drag-and-drop
        delete :bulk_destroy   # Delete multiple images at once
      end
    end
    resources :attribute_values, only: [ :update ], controller: "product_attribute_values", param: :attribute_id
    resources :inventories, only: [ :index, :update ], controller: "product_inventories" do
      collection do
        patch :batch_update
      end
    end
    resources :product_assets, except: [ :show ] do
      collection do
        match :reorder, via: [ :post, :patch ]  # Reorder assets via drag-and-drop (POST for legacy, PATCH for asset-reorder)
        delete :bulk_destroy  # Bulk delete selected assets
      end
    end

    # Advanced product features (Phase 14-16)
    # Configurations and Variants
    resources :configurations, only: [ :index, :new, :create, :edit, :update, :destroy ]
    resources :variants, only: [ :index, :new, :create, :edit, :update, :destroy ] do
      collection do
        post :generate  # Generate all variant combinations
        patch :reorder  # Reorder variants via drag-and-drop
      end
    end

    # Bundle Products
    resources :bundle_products, only: [ :index, :create, :update, :destroy ] do
      collection do
        patch :reorder  # Reorder bundle products
      end
    end

    # Related Products
    resources :related_products, only: [ :index, :create, :destroy ] do
      collection do
        patch :reorder  # Reorder related products
      end
    end

    # Pricing (Phase 17-19)
    resources :prices, only: [ :index, :new, :create, :edit, :update, :destroy ]

    # Version History (Phase 17-19)
    resources :versions, only: [ :index, :show ], controller: "product_versions" do
      member do
        post :revert
      end
      collection do
        get :compare
      end
    end
  end

  # Customer Groups (Phase 17-19)
  resources :customer_groups

  # Import/Export (Phase 17-19)
  resources :imports, only: [ :index, :new, :create ] do
    member do
      get :progress
      get :errors, action: :download_errors
    end
    collection do
      get "template/:type", action: :download_template, as: :download_template
    end
  end

  resources :storages, param: :code do
    member do
      get :inventory
    end

    # Storage inventory management - add products to storage
    resources :inventories, only: [ :new, :create, :update, :destroy ], controller: "storage_inventories"
  end

  resources :product_attributes do
    collection do
      patch :reorder
      get :validate_code
    end
  end

  resources :attribute_groups do
    collection do
      patch :reorder
    end
  end

  resources :labels do
    collection do
      patch :reorder
    end
  end

  # Custom route for catalog items (generates catalog_items_path)
  get "catalogs/:code/items", to: "catalogs#items", as: :catalog_items

  resources :catalogs, param: :code do
    member do
      patch :reorder_items
      get :export
      get :shopify_connection
      post :connect_shopify
      delete :disconnect_shopify
      post :sync_all
      post :toggle_sync_pause
      get :sync_preview
      get :sync_status
      get :sync_alerts
      post "sync_product/:product_id", action: :sync_product, as: :sync_product
    end

    # Catalog Items (add/remove products from catalog)
    # GET /catalogs/:code/products/new - Show add products modal
    # POST /catalogs/:code/products - Add products to catalog
    # DELETE /catalogs/:code/items/:id - Remove product from catalog
    get "products/new", to: "catalog_items#new", as: :new_product
    post "products", to: "catalog_items#create", as: :products
    delete "items/:id", to: "catalog_items#destroy", as: :item

    # Catalog Imports (CSV import of products)
    # GET /catalogs/:code/imports/new - Show import modal
    # POST /catalogs/:code/imports - Process CSV import
    # GET /catalogs/:code/imports/template - Download CSV template
    get "imports/new", to: "catalog_imports#new", as: :new_import
    post "imports", to: "catalog_imports#create", as: :imports
    get "imports/template", to: "catalog_imports#template", as: :imports_template
  end

  # Catalog Item Attribute Values (catalog-specific attribute overrides)
  # POST /catalog_item_attribute_values - Create override
  # PATCH/PUT /catalog_item_attribute_values/:id - Update override
  # DELETE /catalog_item_attribute_values/:id - Delete override
  resources :catalog_item_attribute_values, only: [ :create, :update, :destroy ]

  # Bundle Composer (AJAX search and preview for bundle creation)
  # GET /bundle_composer/search?q=shirt - Search products for bundle
  # GET /bundle_composer/product/:id - Get product details with variants
  # POST /bundle_composer/preview - Validate bundle configuration
  namespace :bundle_composer do
    get :search
    get "product/:id", action: :product_details, as: :product_details
    post :preview
  end
end
