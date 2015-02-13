class TournamentSeasonParticipation < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  STATES = [:accepted, :requested, :denied]
  EVENTS = [:accept, :deny]
  
  belongs_to :season, class_name: 'TournamentSeason'
  belongs_to :competitor
  
  scope :accepted, -> { where(state: 'accepted') }
  
  def self.order_by_state
    if Rails.env.production?
      order_by = ["case"]
      
      STATES.each_with_index.map do |status, index|
        order_by << "WHEN state='#{status}' THEN #{index}"
      end
      
      order_by << "end"
      order(order_by.join(" "))
    else
      order("FIELD(state, '#{STATES.join("','")}')")
    end
  end
  
  validates :season_id, presence: true
  validates :competitor_id, presence: true, uniqueness: { scope: :season_id }
  
  attr_accessible :season_id
  
  after_initialize :set_initial_state
  before_create :set_user
      
  state_machine :state, initial: :requested do
    state :requested do
      validate :competitors_limit_of_tournament_not_reached  
    end
    
    state :accepted do
      validate :competitors_limit_of_tournament_not_reached  
    end
    
    event :accept do
      transition [:requested, :denied] => :accepted
    end
    
    event :deny do
      transition [:requested, :accepted] => :denied
    end
    
    after_transition [:requested, :denied] => :accepted do |season_participation, transition|
      season_participation.season.activate
    end
  end
  
  private 
  
  def set_initial_state
    self.state ||= :requested
  end
  
  def competitors_limit_of_tournament_not_reached
    unless season.competitors_needed?
      errors[:base] << I18n.t('activerecord.errors.models.tournament_season_participation.attributes.state.tournament_competitors_limit_reached')
    end
  end
  
  def set_user
    self.user_id = competitor.user_id unless user_id.present?
  end
end