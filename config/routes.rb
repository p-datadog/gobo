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
  get '/debugger_test/binary_data_param', to: 'debugger_test#binary_data_param'
  get '/debugger_test/binary_data', to: 'debugger_test#binary_data'
  get '/debugger_test/exception_message', to: 'debugger_test#exception_message', as: 'debugger_test_exception_message'
  get '/debugger_test/exception_standard', to: 'debugger_test#exception_standard'
  get '/debugger_test/exception_overridden', to: 'debugger_test#exception_overridden'
  get '/debugger_test/exception_non_string', to: 'debugger_test#exception_non_string'
  get '/debugger_test/json_error', to: 'debugger_test#json_error', as: 'debugger_test_json_error'
  get '/probes', to: 'probes#index'
  get '/code_tracker', to: 'code_tracker#index'
  post '/probes/:id/send_status', to: 'probes#send_status', as: 'send_probe_status'
end
