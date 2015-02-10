class TournamentMatch < ActiveRecord::Base
  belongs_to :season, class_name: 'TournamentSeason'
  belongs_to :home_competitor, class_name: 'Competitor'
  belongs_to :away_competitor, class_name: 'Competitor'
  belongs_to :winner_competitor, class_name: 'Competitor'
  belongs_to :loser_competitor, class_name: 'Competitor'
  
  validates :season_id, presence: true
  validates :home_competitor_id, presence: true
  validates :away_competitor_id, presence: true
  validates :date, presence: true
  
  attr_accessible :season_id, :matchday, :home_competitor_id, :away_competitor_id, :winner_competitor_id, :loser_competitor_id, :draw, :date
end