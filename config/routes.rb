Chibi::Application.routes.draw do
  resources :messages, :only => [:index, :create, :show]
  resources :replies,  :only => [:index, :update]
  resources :users, :only => :index

  mount Resque::Server.new, :at => "/resque"
end
