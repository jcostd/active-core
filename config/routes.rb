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
    resources :attendances,   only: [ :index ], module: :members
    resources :sales,         only: [ :index ], module: :members
  end

  resources :users
  namespace :preferences do
    resource :theme, only: [ :update ]
  end

  resources :disciplines do
    resources :members,     only: [ :index ], module: :disciplines
    resources :attendances, only: [ :create, :destroy ], module: :disciplines
  end
  resources :products

  resources :sales, only: [ :index, :new, :create, :show, :destroy ]
  resources :subscriptions, only: [ :index, :edit, :update, :destroy ]

  resources :reports, only: [ :index, :show ], param: :report_type
  resource :gym_profile, only: [ :show, :edit, :update ]
  resources :feedbacks, only: [ :new, :create ]

  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboard#index"

  # kiosk dell'iPad: registro presenze del mese
  namespace :kiosk do
    root to: "disciplines#index"

    resources :disciplines, only: [ :index, :show ] do
      resources :attendances, only: [ :create, :destroy ]
      resources :member_searches, only: [ :index ]
    end
  end
end
