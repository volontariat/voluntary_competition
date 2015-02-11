class Competition::MatchesController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource class: 'TournamentMatch'
  
  def index
    @season = TournamentSeason.find(params[:season_id])
    @matches = @season.matches.where('matchday = ?', params[:matchday])
    render partial: 'competition/matches/collection', layout: false if request.xhr?
  end
  
  def updates
    @season = TournamentSeason.find(params[:season_id])
    @matches = TournamentMatch.update(params[:matches].keys, params[:matches].values)
    
    render layout: false if request.xhr?
  end
end