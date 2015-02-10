class Competition::ExerciseTypesController < ::Competition::ApplicationController
  include ::Competition::BaseController
  include Applicat::Mvc::Controller::Resource
  
  load_and_authorize_resource
  
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  
  respond_to :html
  
  def index
  end
  
  def autocomplete
    render json: (
      ExerciseType.select('id, name').where("name LIKE ?", "#{params[:term].to_s.strip}%").order(:name).limit(10).map{|a| { id: a.id, value: a.name } }
    ), root: false
  end
  
  def show
    @exercise_type = ExerciseType.find(params[:id])
  end
  
  def new
    @exercise_type = ExerciseType.new(params[:exercise_type])
  end
  
  def create
    @exercise_type = ExerciseType.new(params[:exercise_type])
    
    if @exercise_type.save
      redirect_to [:competition, @exercise_type], notice: t('general.form.successfully_created')
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @exercise_type.update_attributes(params[:exercise_type])
      redirect_to [:competition, @exercise_type], notice: t('general.form.successfully_updated')
    else
      render :edit
    end
  end

  def destroy
    @exercise_type.destroy
    redirect_to competition_exercise_types_path, notice: t('general.form.destroyed')
  end
  
  def resource
    @exercise_type
  end
  
  private
  
  def not_found
    redirect_to competition_exercise_types_path, notice: t('general.exceptions.not_found')
  end
end