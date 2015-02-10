module GameAndExerciseTypeAssociation
  extend ActiveSupport::Concern
          
  included do
    belongs_to :game_and_exercise_type
    
    validates :game_and_exercise_type_id, presence: true
    validates :exercise_type_name, presence: true, if: 'game_and_exercise_type_id.blank? && exercise_type_id.blank?'
    validates :game_name, presence: true, if: 'game_and_exercise_type_id.blank? && game_id.blank?'
    
    attr_accessible :game_and_exercise_type_id, :exercise_type_id, :exercise_type_name, :game_id, :game_name
    
    attr_accessor :exercise_type_id, :exercise_type_name, :game_id, :game_name
    
    before_validation :set_game_and_exercise_type_id
    
    private
    
    def set_game_and_exercise_type_id
      return if game_and_exercise_type_id.present?
      
      self.game_id = Game.where(name: game_name).first_or_create!.id unless game_name.blank? || game_id.present?
      self.exercise_type_id = ExerciseType.where(name: exercise_type_name).first_or_create!.id unless exercise_type_name.blank? || exercise_type_id.present?
      
      unless game_id.blank? || exercise_type_id.blank?
        self.game_and_exercise_type_id = GameAndExerciseType.where(game_id: game_id, exercise_type_id: exercise_type_id).first_or_create!.id
      end
    end
  end
end