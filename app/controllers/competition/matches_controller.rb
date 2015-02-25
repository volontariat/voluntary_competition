class Competition::MatchesController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  include ::Competition::Bracket
  
  load_and_authorize_resource class: 'TournamentMatch'
  
  def index
    @season = TournamentSeason.find(params[:season_id])
    @can_update_season = can?(:update, @season)
    @matches = @season.matches.where('matchday = ?', params[:matchday])
    render partial: 'competition/matches/collection', layout: false if request.xhr?
  end
  
  def updates
    @season = TournamentSeason.find(params[:season_id])
    
    if params[:matches].present?
      @input_matches = @season.consider_matches(params[:matches], params[:matchday])
    else
      @input_matches = []
    end
    
    unless params[:from_bracket].blank? || @input_matches.empty? || @input_matches.select{ |m| !m.errors.empty? }.any?
      @season.reload
      get_bracket_variables
    end
     
    render layout: false if request.xhr?
  end
end