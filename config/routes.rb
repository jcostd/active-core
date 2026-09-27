Rails.application.routes.draw do
  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

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
    resource :theme, only: [ :update ]
  end

  resources :disciplines do
    resources :members, only: [ :index ], module: :disciplines
  end
  resources :products

  resources :sales, only: [ :index, :new, :create, :show, :destroy ]
  resources :subscriptions, only: [ :index, :edit, :update, :destroy ]
  resources :access_logs, only: [ :index, :destroy ]

  resources :reports, only: [ :index, :show ], param: :report_type
  resource :gym_profile, only: [ :edit, :update ]
  resources :feedbacks, only: [ :new, :create ]

  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboard#index"

  # --- MODALITÀ KIOSK (iPad Appello) ---
  namespace :kiosk do
    root to: "disciplines#index"

    resources :disciplines, only: [ :index, :show ] do
      resources :access_logs, only: [ :create ]
      resources :member_searches, only: [ :index ]
    end
  end
end
