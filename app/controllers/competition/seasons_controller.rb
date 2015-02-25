class Competition::SeasonsController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  include ::Competition::Bracket
  
  load_and_authorize_resource class: 'TournamentSeason', except: [:bracket]
  
  def bracket
    @season = TournamentSeason.find(params[:id])
    @can_update_season = can?(:update, @season)
    get_bracket_variables if @season.active?

    options = request.xhr? ? { layout: false } : {}
    render 'competition/tournament_seasons/bracket', options
  end
  
  def resource
    @season
  end
end
