Chibi::Application.routes.draw do
  resources :messages, :only => [:index, :create]
  resources :replies,  :only => :index
  resources :chats, :only => :index
  resources :phone_calls, :only => :create, :defaults => { :format => 'xml' }
  resources :missed_calls, :only => :create

  resources :users, :only => [:index, :destroy, :show] do
    resources :messages, :only => :index
    resources :replies, :only => :index
  end

  mount Resque::Server.new, :at => "/resque"
end
