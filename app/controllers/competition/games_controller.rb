class Competition::GamesController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource
  
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  
  respond_to :html
  
  def index
  end
  
  def show
    @game = Game.find(params[:id])
  end
  
  def new
    @game = Game.new(params[:game])
  end
  
  def create
    @game = Game.new(params[:game])
    
    if @game.save
      redirect_to [:competition, @game], notice: t('general.form.successfully_created')
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @game.update_attributes(params[:game])
      redirect_to [:competition, @game], notice: t('general.form.successfully_updated')
    else
      render :edit
    end
  end

  def destroy
    @game.destroy
    redirect_to competition_games_path, notice: t('general.form.destroyed')
  end
  
  def resource
    @game
  end
  
  private
  
  def not_found
    redirect_to competition_games_path, notice: t('general.exceptions.not_found')
  end
end