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
    already_played_competitor_ids = @season.rankings.where(matchday: params[:matchday], played: true).map(&:competitor_id)
    @matches = TournamentMatch.update(params[:matches].keys, params[:matches].values)
    
    valid_matches = @matches.select do |m| 
      m.errors.empty? && (m.winner_competitor_id.present? || !m.draw.nil?) && !already_played_competitor_ids.include?(m.home_competitor_id)
    end
    
    @season.consider_matches(valid_matches)
    
    render layout: false if request.xhr?
  end
end