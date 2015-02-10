class GameAndExerciseType < ActiveRecord::Base
  belongs_to :game
  belongs_to :exercise_type
  
  validates :game_id, presence: true
  validates :exercise_type, presence: true, uniqueness: { scope: :game_id }
end