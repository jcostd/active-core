Rails.application.routes.draw do
  # ============================================================================
  # 1. AUTHENTICATION
  # ============================================================================
  resource :session
  resources :passwords, param: :token

  concern :searchable do
    resources :searches, only: [ :index ]
  end

  namespace :members do
    concerns :searchable
  end

  # ============================================================================
  # 2. ANAGRAFICA (Registry)
  # ============================================================================
  resources :members do
    resources :subscriptions, only: [ :index ], module: :members
    resources :access_logs,   only: [ :index ], module: :members
    resources :sales,         only: [ :index ], module: :members
  end

  resources :users
  namespace :preferences do
    resource :theme, only: [ :show, :update ]
    resource :language, only: [ :update ]
  end

  # ============================================================================
  # 3. CATALOGO (Catalog)
  # ============================================================================
  resources :disciplines do
    resources :members, only: [ :index ], module: :disciplines
  end
  resources :products

  # ============================================================================
  # 4. AMMINISTRAZIONE & VENDITE (Accounting)
  # ============================================================================
  resources :sales, only: [ :index, :new, :create, :show, :destroy ]

  resources :subscriptions, only: [ :index, :edit, :update, :destroy ]
  resources :receipt_counters

  # ============================================================================
  # 5. ACCESSI (Access Control)
  # ============================================================================
  resources :access_logs, only: [ :index, :new, :create ]

  # ============================================================================
  # 6. REPORTING & UTILITY
  # ============================================================================
  resources :reports, only: [ :index, :show ], param: :report_type
  resources :feedbacks, only: [ :new, :create ]

  # ============================================================================
  # ROOT & SYSTEM
  # ============================================================================
  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboard#index"

  # --- KIOSK MODE (iPad Appello) ---
  namespace :kiosk do
    root to: "disciplines#index"

    resources :disciplines, only: [ :index, :show ] do
      resources :access_logs, only: [ :create, :destroy ]
      resources :member_searches, only: [ :index ]
    end
  end
end
