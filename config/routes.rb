Rails.application.routes.draw do
  get '/products/competition', to: redirect('/competition'), as: 'competition_product'
  get '/competition' => 'product/competition#index'
  
  namespace :competition do
    resources :games
    resources :exercise_types
    resources :tournaments
    
    resources :seasons, only: [] do
      resources :participations, controller: 'season_participations', only: [:index, :new, :create] 
      resources :rankings, only: [:index]
      
      resources :matches, only: [:index] do
        collection do
          put :updates
        end
      end
      
      member do
        get :bracket
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
