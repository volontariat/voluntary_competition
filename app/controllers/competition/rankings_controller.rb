class Competition::RankingsController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource class: 'TournamentSeasonRanking'
  
  def index
    @season = TournamentSeason.find(params[:season_id])
    
    if @season.tournament.with_group_stage?
      rankings = @season.rankings.order('position ASC')
      groups_matchday = params[:matchday].to_i > @season.tournament.last_matchday_of_group_stage ? @season.tournament.last_matchday_of_group_stage : params[:matchday]
      @rankings = rankings.where('group_number IS NOT NULL AND matchday = ?', groups_matchday).order('group_number ASC').group_by(&:group_number)
      @rankings[:global] = rankings.where('group_number IS NULL AND matchday = ?', params[:matchday])
    else
      @rankings = @season.rankings.where('matchday = ?', params[:matchday]).order('position ASC')
    end
    
    render partial: ranking_collection_partial, layout: false if request.xhr?
  end
  
  def ranking_collection_partial
    "competition/rankings/#{@season.tournament.with_group_stage? ? 'global_and_group_collections' : 'collection'}"
  end
  
  helper_method :ranking_collection_partial
  
  def resource
    @ranking
  end
end