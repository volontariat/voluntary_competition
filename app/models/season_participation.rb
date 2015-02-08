class SeasonParticipation < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :season
  belongs_to :competitor
  
  validates :season_id, presence: true
  validates :competitor_id, presence: true, uniqueness: { scope: :season_id }
  
  attr_accessible :season_id
  
  private 
  
  def competitors_limit_of_tournament_not_reached 
    unless season.tournament.more_competitors_needed?(season)
      errors[:base] << I18n.t('activerecord.errors.models.season_participation.attributes.state.tournament_competitors_limit_reached')
    end
  end
end