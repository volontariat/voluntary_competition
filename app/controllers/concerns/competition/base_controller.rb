module Competition
  module BaseController
    extend ActiveSupport::Concern
      
    def application_navigation
      :main_competition
    end
    
    def navigation_product_path
      competition_product_path
    end
    
    def navigation_product_name
      'Competition'
    end
  end
end