class Competition::TournamentsController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource
  
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  
  respond_to :html
  
  def index
  end
  
  def show
  end
  
  def new
    @tournament = current_user.tournaments.new(params[:tournament])
  end
  
  def create
    @tournament = current_user.tournaments.new(params[:tournament])
    
    if @tournament.save
      redirect_to [:competition, @tournament], notice: t('general.form.successfully_created')
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @tournament.update_attributes(params[:tournament])
      redirect_to [:competition, @tournament], notice: t('general.form.successfully_updated')
    else
      render :edit
    end
  end

  def destroy
    @tournament.destroy
    redirect_to competition_tournaments_path, notice: t('general.form.destroyed')
  end
  
  def resource
    @tournament
  end
  
  private
  
  def not_found
    redirect_to competition_tournaments_path, notice: t('general.exceptions.not_found')
  end
end