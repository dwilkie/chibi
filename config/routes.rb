Chibi::Application.routes.draw do
  resources :messages, :only => [:index, :create]
  resources :replies,  :only => :index

  resources :phone_calls, :only => :index
  resources :phone_calls, :only => :create, :defaults => { :format => 'xml' }

  resources :missed_calls, :only => :create

  resource :overview, :only => :show

  resources :chats, :only => :index do
    resources :messages, :only => :index
    resources :replies, :only => :index
    resources :phone_calls, :only => :index
  end

  resources :users, :only => [:index, :destroy, :show] do
    resources :messages, :only => :index
    resources :replies, :only => :index
    resources :phone_calls, :only => :index
  end

  mount Resque::Server, :at => "/resque"
end
