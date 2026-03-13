Rails.application.routes.draw do
  root   'static_pages#home'
  get    '/help',    to: 'static_pages#help'
  get    '/about',   to: 'static_pages#about'
  get    '/contact', to: 'static_pages#contact'
  get    '/signup',  to: 'users#new'
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'
  resources :users do
    member do
      get :following, :followers
    end
  end
  resources :account_activations, only: [:edit]
  resources :password_resets,     only: [:new, :create, :edit, :update]
  resources :microposts,          only: [:create, :destroy]
  resources :relationships,       only: [:create, :destroy]
  get '/microposts', to: 'static_pages#home'
  get '/microposts/:id/vote/:job_id', to: 'static_pages#vote'
  get '/debugger_test/calculate', to: 'debugger_test#calculate'
  get '/debugger_test/circuit_breaker', to: 'debugger_test#circuit_breaker'
  get '/debugger_test/binary_data', to: 'debugger_test#binary_data'
  get '/probes', to: 'probes#index'
  post '/probes/:id/send_status', to: 'probes#send_status', as: 'send_probe_status'
end
