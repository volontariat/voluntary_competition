class Tournament < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  include GameAndExerciseTypeAssociation
  
  belongs_to :game_and_exercise_type
  belongs_to :user
  belongs_to :current_season, class_name: 'TournamentSeason'
  
  has_many :seasons, class_name: 'TournamentSeason', dependent: :destroy
  
  validates :game_and_exercise_type_id, presence: true
  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: [:user_id, :game_and_exercise_type_id] }
  
  attr_accessible :name, :first_season_name, :competitors_limit
  
  attr_accessor :first_season_name
  
  after_create :create_first_season
    
  private
  
  def create_first_season
    update_attribute(:current_season_id, seasons.create!(name: first_season_name).id)
  end
end