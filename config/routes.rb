require "resque_web"

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

  resource :report, :only => [:create, :show, :destroy]

  mount ResqueWeb::Engine => "/resque"
end
