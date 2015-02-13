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
    @matches = @season.consider_matches(params[:matches], params[:matchday])
    
    render layout: false if request.xhr?
  end
end