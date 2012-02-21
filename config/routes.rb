Chibi::Application.routes.draw do
  resources :messages, :only => [:index, :create]
  resources :replies,  :only => :index

  resources :users, :only => [:index, :destroy, :show] do
    resources :messages, :only => :index
    resources :replies, :only => :index
  end

  mount Resque::Server.new, :at => "/resque"
end
