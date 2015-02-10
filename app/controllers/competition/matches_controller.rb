class Competition::MatchesController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource class: 'TournamentMatch'
  
  def index
    @season = TournamentSeason.find(params[:season_id])
    @matches = @season.matches.where('matchday = ?', params[:matchday])
    render partial: 'competition/tournament_matches/collection', layout: false if request.xhr?
  end
end