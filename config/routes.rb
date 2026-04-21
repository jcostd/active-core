Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  concern :searchable do
    resources :searches, only: [ :index ]
  end

  namespace :members do
    concerns :searchable
  end

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

  resources :disciplines do
    resources :members, only: [ :index ], module: :disciplines
  end
  resources :products

  resources :sales, only: [ :index, :new, :create, :show, :destroy ]
  resources :subscriptions, only: [ :index, :edit, :update, :destroy ]
  resources :access_logs, only: [ :index, :destroy ]

  resources :reports, only: [ :index, :show ], param: :report_type
  resources :feedbacks, only: [ :new, :create ]

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
