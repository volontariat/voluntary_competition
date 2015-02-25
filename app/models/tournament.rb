class Tournament < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  include GameAndExerciseTypeAssociation
  
  SYSTEM_TYPES = %w(round_robin single_elimination)
  
  belongs_to :game_and_exercise_type
  belongs_to :user
  belongs_to :current_season, class_name: 'TournamentSeason'
  
  has_many :seasons, class_name: 'TournamentSeason', dependent: :destroy
  
  validates :game_and_exercise_type_id, presence: true
  validates :system_type, presence: true, inclusion: { in: SYSTEM_TYPES.length.times.to_a }
  validate :system_type_requirements
  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: [:user_id, :game_and_exercise_type_id] }
  validates :competitors_limit, presence: true
  
  attr_accessible :system_type, :with_second_leg, :name, :first_season_name, :competitors_limit
  
  attr_accessor :first_season_name
  
  after_create :create_first_season
  
  def is_round_robin?
    system_type == 0
  end
  
  def is_single_elimination?
    system_type == 1
  end
    
  private
  
  def system_type_requirements
    case system_type
    when 1
      unless competitors_limit & (competitors_limit - 1) == 0
        errors[:system_type] << I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_must_be_power_of_two')
      end
      
      if competitors_limit < 4
        errors[:system_type] << I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_should_be_at_least_4')
      end
    end
  end
  
  def create_first_season
    update_attribute(:current_season_id, seasons.create!(name: first_season_name).id)
  end
end