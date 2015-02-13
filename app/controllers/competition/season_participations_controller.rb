class Competition::SeasonParticipationsController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource class: 'TournamentSeasonParticipation'
  
  def new
    @season = TournamentSeason.find(params[:season_id])
    @season_participation = TournamentSeasonParticipation.new
    find_competitors
    
    params[:season_participation] ||= {}
    params[:season_participation][:competitor_ids] ||= @season.participations.where(competitor_id: @competitors.map(&:id)).map(&:competitor_id)
    
    render layout: false if request.xhr?
  end
  
  def index
    @season = TournamentSeason.find(params[:season_id])
    @season_participations = @season.participations.order_by_state.paginate(per_page: 25, page: params[:page] || 1)
    render partial: 'competition/season_participations/collection', layout: false if request.xhr?
  end
  
  def create
    params[:season_participation] ||= {}
    @season = TournamentSeason.find(params[:season_id])
    @season_participation = current_user.join_tournament_season_with_competitors(@season, params[:season_participation][:competitor_ids])
    
    if @season_participation.errors.any?
      find_competitors
    else
      @season_participations = @season.participations.order_by_state.paginate(per_page: 25, page: params[:page] || 1)
    end
    
    render layout: false if request.xhr?
  end
  
  def accept
    @season_participation.accept
    
    render layout: false
  end
  
  def deny
    @season_participation.deny
    
    render layout: false
  end
  
  private
  
  def find_competitors
    @competitors = current_user.competitors.where(game_and_exercise_type_id: @season.tournament.game_and_exercise_type_id).order('name')    
  end
end