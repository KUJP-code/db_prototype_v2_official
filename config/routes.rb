# frozen_string_literal: true

Rails.application.routes.draw do
  get 'quick_bookings/new'
  # My DB analytics dashboard
  authenticate :user, ->(user) { user.admin? } do
    mount MissionControl::Jobs::Engine, at: '/jobs'
    mount PgHero::Engine, at: 'pghero'
  end
  
  # custom routes
  get '/choco25', to: 'redirects#choco25'

  scope '(/:locale)', locale: /ja|en/ do
    get '/schools/:school_id/quick_booking_timeslots', to: 'quick_bookings#timeslots', defaults: { format: :json }
    resource :quick_booking, only: [:new, :create] do
      get 'thank_you', on: :collection
    end
    devise_for :users, path: 'auth', controllers: {
      registrations: 'users/registrations',
      sessions: 'users/sessions'
    }
    resources :schools, only: [:index]
    # Require users to be signed in to view these resources
    authenticate :user do
      resources :adjustments, only: %i[edit]
      resources :areas
      resources :bulk_events, only: %i[index update]
      post 'bulk_events/release/:name',
           to: 'bulk_events#release', as: :release_event
      resources :charts, only: %i[show index]
      patch 'children/attended_seasonal/:event_name',
            to: 'children#attended_seasonal', as: :attended_seasonal
      resources :children
      resources :csvs, only: %i[index]
      resources :document_uploads, only: %i[destroy index]
      resources :events, except: %i[destroy]
      resources :invoices, except: %i[edit]
      resources :inquiries, except: %i[show]
      resources :merch_items
      resources :price_lists, except: %i[destroy show]
      resources :schools, except: [:index]
      resources :setsumeikais
      resources :staff_users, except: %i[show]
      resources :surveys, except: %i[destroy]
      resources :survey_responses, only: %i[create update]
      resources :time_slots, except: %i[create destroy show]
      resources :uploads, only: %i[create new]
      resources :users

      # Mailer subscription routes
      resources :mailer_subscriptions, only: %i[index create update]

      # Non-REST routes for Children controller
      get 'child/find_child', to: 'children#find_child', as: :find_child
      # Non-REST routes for CSVs controller
      post 'csv/upload', to: 'csvs#upload', as: :upload_csv
      post 'csv/update', to: 'csvs#update', as: :update_csv
      get 'csv/download', to: 'csvs#download', as: :download_csv
      get 'csv/emails/:event', to: 'csvs#emails', as: :download_emails
      get 'csv/no_photo_emails/:event', to: 'csvs#no_photo_emails',
                                        as: :download_no_photo_emails
      get 'csv/photo_kids/:event', to: 'csvs#photo_kids',
                                   as: :download_photo_kids
      get 'csv/signups/:event', to: 'csvs#download_signups', as: :download_signups


      # Non-REST routes for Events controller
      get 'event/diff_school', to: 'events#show', as: :diff_school_path

      # Non-REST routes for Invoices controller
      patch 'confirm_invoice', to: 'invoices#confirm', as: :confirm_invoice
      post 'confirm_invoice', to: 'invoices#confirm', as: :confirm_new_invoice
      put 'copy_invoice', to: 'invoices#copy', as: :copy_invoice
      post 'merge_invoices', to: 'invoices#merge', as: :merge_invoices
      post 'seen_invoice', to: 'invoices#seen', as: :seen_invoice

      # Non-REST routes for Users controller
      post 'user/add_child', to: 'users#add_child', as: :add_child
      post 'user/remove_child', to: 'users#remove_child', as: :remove_child
      post 'user/merge_children', to: 'users#merge_children', as: :merge_children

      # Ensures just the locale also goes to root
      get '/:locale', to: 'users#profile'
    end
  end

  # Setsu calendar school API endpoint
  get 'setsu_schools',
      constraints: ->(req) { req.format == :json },
      to: 'schools#index'

  # Legacy API for GAS Sheets
  get 'gas_schools', to: 'sheets_apis#schools'
  get 'gas_inquiries', to: 'sheets_apis#inquiries'
  get 'gas_summary', to: 'sheets_apis#summary'
  # Don't blame me, the sheet makes a post request
  post 'gas_inquiries', to: 'sheets_apis#inquiries'
  post 'gas_update', to: 'sheets_apis#update'

  # Inquiry API endpoint
  post 'create_inquiry', to: 'inquiries#create'

  # Health check endpoint for EB load balancer
  get '/health_check', to: proc { [200, {}, ['success']] }

  # Route to auto-unsubscribe from emails
  resources :mailer_subscription_unsubcribes, only: %i[show update]

  scope '(/:locale)', locale: /ja|en/ do
    # Allow unauthenticated document_uploads
    resources :document_uploads, only: %i[create new show]
  end

  # Defines the root path route ("/")
  authenticated :user do
    root to: 'users#profile', as: :authenticated_root
  end
  root to: 'splashes#landing'
end
