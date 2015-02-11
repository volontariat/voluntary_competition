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
      resources :matches, only: [:index] do
        collection do
          put :updates
        end
      end
    end
    
    resources :season_participations, only: [] do
      member do
        put :accept
        put :deny
      end
    end
    
    resources :competitors
    resources :matches, only: [:show]
  end
end
