class Competition::ApplicationController < ::ApplicationController
  protected

  def voluntary_application_stylesheets
    ['voluntary/application', 'application'] 
  end

  def voluntary_application_javascripts
    ['voluntary/application', 'voluntary_competition/application', 'application'] 
  end
end