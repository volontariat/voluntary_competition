class Competition::CompetitorsController < ::Competition::ApplicationController
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
    @competitor = current_user.competitors.new(params[:competitor])
  end
  
  def create
    @competitor = current_user.competitors.new(params[:competitor])
    
    if @competitor.save
      redirect_to [:competition, @competitor], notice: t('general.form.successfully_created')
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @competitor.update_attributes(params[:competitor])
      redirect_to [:competition, @competitor], notice: t('general.form.successfully_updated')
    else
      render :edit
    end
  end

  def destroy
    @competitor.destroy
    redirect_to competition_competitors_path, notice: t('general.form.destroyed')
  end
  
  def resource
    @competitor
  end
  
  private
  
  def not_found
    redirect_to competition_competitors_path, notice: t('general.exceptions.not_found')
  end
end