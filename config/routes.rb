require 'sidekiq/web'

Rails.application.routes.draw do
  root "welcome#index"

  resources :messages, :only => :create
  resources :phone_calls, :only => :create, :defaults => { :format => 'xml' }
  resources :missed_calls, :only => :create
  resources :delivery_receipts, :only => :create
  resources :call_data_records, :only => :create, :defaults => { :format => 'xml' }

  resource :overview,         :only => :show
  resource :user_demographic, :only => :show
  resource :interaction,      :only => :show

  resources :chats, :only => :index do
    resource :interaction, :only => :show
  end

  resources :users, :only => [:index, :show] do
    resource :interaction, :only => :show
  end

  resources :test_messages, :only => [:new, :create]

  resource :report, :only => [:create, :show, :destroy]

  Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
    username == Rails.application.secrets[:http_basic_auth_admin_user] && password == Rails.application.secrets[:http_basic_auth_admin_password]
  end

  mount Sidekiq::Web => '/sidekiq'
end
