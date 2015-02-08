Rails.application.routes.draw do
  get '/products/competition', to: redirect('/competition'), as: 'competition_product'
  get '/competition' => 'product/competition#index'
  
  namespace :competition do
    resources :tournaments
    
    resources :seasons do
      resources :participations, controller: 'season_participations', only: [:new, :create] 
    end
    
    resources :competitors
  end
end
