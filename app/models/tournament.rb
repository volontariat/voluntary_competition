class Tournament < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :user
  belongs_to :current_season, class_name: 'TournamentSeason'
  
  has_many :seasons, class_name: 'TournamentSeason', dependent: :destroy
  
  validates :user_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }
  
  attr_accessible :name, :first_season_name, :competitors_limit
  
  attr_accessor :first_season_name
  
  after_create :create_first_season
  
  def more_competitors_needed?(season = nil)
    season ||= current_season
    season.no_competitors_needed?(1, competitors_limit: competitors_limit) == false
  end
    
  
  private
  
  def create_first_season
    season = seasons.create!(name: first_season_name)
    update_attribute(:current_season_id, season.id)
  end
end