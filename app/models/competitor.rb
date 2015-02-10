class Competitor < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  include GameAndExerciseTypeAssociation
  
  belongs_to :user
  
  has_many :season_participations, dependent: :destroy
  
  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: [:user_id, :game_and_exercise_type_id] }
  
  attr_accessible :name
end