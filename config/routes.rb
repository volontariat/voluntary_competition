Rails.application.routes.draw do
  get '/products/competition', to: redirect('/competition'), as: 'competition_product'
  get '/competition' => 'product/competition#index'
  
  namespace :competition do
    resources :games do
      collection do
        get :autocomplete
      end
    end
    
    resources :exercise_types do
      collection do
        get :autocomplete
      end
    end
    
    resources :tournaments
    
    resources :seasons do
      resources :participations, controller: 'season_participations', only: [:index, :new, :create] 
    end
    
    resources :season_participations, only: [] do
      member do
        put :accept
        put :deny
      end
    end
    
    resources :competitors
  end
end
