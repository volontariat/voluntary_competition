class Competition::RankingsController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource class: 'TournamentSeasonRanking'
  
  def index
    @season = TournamentSeason.find(params[:season_id])
    @rankings = @season.rankings.where('matchday = ?', params[:matchday]).order('position ASC')
    
    render partial: 'competition/rankings/collection', layout: false if request.xhr?
  end
end