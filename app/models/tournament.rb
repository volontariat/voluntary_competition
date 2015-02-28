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
  validates :competitors_limit, presence: true, numericality: { only_integer: true }
  validates :groups_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 2 }, if: 'with_group_stage?'
  
  attr_accessible :system_type, :name, :with_second_leg, :with_group_stage, :groups_count, :third_place_playoff, :first_season_name, :competitors_limit
  
  attr_accessor :first_season_name
  
  before_validation :reset_elimination_attributes_if_round_robin
  after_create :create_first_season
  
  def is_round_robin?
    system_type == 0
  end
  
  def is_single_elimination?
    system_type == 1
  end
  
  def competitors_per_group
    competitors_limit / groups_count
  end
  
  def last_matchday_of_group_stage
    first_leg_matchdays_count = competitors_per_group % 2 == 0 ? (competitors_per_group - 1) : competitors_per_group
    with_second_leg? ? (first_leg_matchdays_count * 2) : first_leg_matchdays_count
  end
  
  def elimination_stage_competitors_count
    with_group_stage? ? groups_count * 2 : competitors_limit
  end
    
  private
  
  def reset_elimination_attributes_if_round_robin
    self.with_group_stage = false if is_round_robin?
    self.groups_count = nil if is_round_robin?
    self.third_place_playoff = false if is_round_robin?
    
    return true
  end
  
  def system_type_requirements
    case system_type
    when 1
      unless groups_count.blank? || (elimination_stage_competitors_count & (elimination_stage_competitors_count - 1) == 0)
        errors[:competitors_limit] << I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_must_be_power_of_two')
      end
      
      if competitors_limit < 4
        errors[:competitors_limit] << I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_should_be_at_least_4')
      end
      
      if with_group_stage?
        if competitors_limit % groups_count != 0
          errors[:groups_count] << I18n.t('activerecord.errors.models.tournament.attributes.system_type.groups_count_invalid')
        elsif competitors_per_group < 3
          errors[:groups_count] << I18n.t('activerecord.errors.models.tournament.attributes.system_type.groups_with_at_least_3_competitors')
        end
      end
    end
  end
  
  def create_first_season
    update_attribute(:current_season_id, seasons.create!(name: first_season_name).id)
  end
end