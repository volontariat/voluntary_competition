class Competition::SeasonParticipationsController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource
  
  def new
    build_resource

    render layout: false if request.xhr?
  end
  
  def index
    @season = TournamentSeason.find(params[:season_id])
    @season_participations = @season.participations.order_by_state.paginate(per_page: 25, page: params[:page] || 1)
    render partial: 'competition/season_participations/collection', layout: false if request.xhr?
  end
  
  def create
    build_resource; error = nil; @tournament = @season.tournament
    
    @season.participations.where(competitor_id: @left_competitor_ids).destroy_all if @left_competitor_ids.any?
    
    if @already_joined_competitor_ids.empty? && params[:season_participation][:competitor_ids].empty?
      @season_participation.errors[:base] << I18n.t('season_participations.create.please_select_at_least_one_competitor')
    else
      no_competitors_needed = @season.no_competitors_needed?(
        @new_competitor_ids.length, 
        new_and_already_joined_competitors_count: params[:season_participation][:competitor_ids].length,
        already_joined_competitors_count: @already_joined_competitor_ids.length,
        competitors_limit: @tournament.competitors_limit
      )
      @season_participation.errors[:base] << no_competitors_needed unless no_competitors_needed == false
    end
    
    unless @season_participation.errors.any?
      errors = @season.create_participations_by_competitor_ids(@new_competitor_ids, current_user.id)
      @season_participation.errors[:base] += errors if errors.any?
    end
    
    unless @season_participation.errors.any?
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
  
  def build_resource
    params[:season_participation] ||= {}
    @season = TournamentSeason.find(params[:season_id])
    @already_joined_competitor_ids = @season.participations.where(competitor_id: current_user.competitors.map(&:id)).map(&:competitor_id)
    params[:season_participation][:competitor_ids] ||= @already_joined_competitor_ids if action_name == 'new'
    params[:season_participation][:competitor_ids] ||= []
    params[:season_participation][:competitor_ids] = params[:season_participation][:competitor_ids].map(&:to_i)
    @left_competitor_ids = @already_joined_competitor_ids.select{|id| !params[:season_participation][:competitor_ids].include?(id) }
    @new_competitor_ids = params[:season_participation][:competitor_ids].select{|id| !@already_joined_competitor_ids.include?(id) }
    @season_participation = SeasonParticipation.new
  end
end