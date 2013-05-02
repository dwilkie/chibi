Chibi::Application.routes.draw do
  resources :messages, :only => :create
  resources :phone_calls, :only => :create, :defaults => { :format => 'xml' }
  resources :missed_calls, :only => :create
  resources :delivery_receipts, :only => :create

  resource :overview,         :only => :show
  resource :user_demographic, :only => :show
  resource :interaction,      :only => :show

  resources :chats, :only => :index do
    resource :interaction, :only => :show
  end

  resources :users, :only => [:index, :destroy, :show] do
    resource :interaction, :only => :show
  end

  mount Resque::Server, :at => "/resque"
end
