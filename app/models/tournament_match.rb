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
  validate :result_not_changed
  
  attr_accessible :season_id, :matchday, :home_competitor_id, :away_competitor_id, :home_goals, :away_goals, :date

  before_validation :set_winner_and_loser_or_draw
  
  private
  
  def set_winner_and_loser_or_draw
    if home_goals == away_goals
      self.winner_competitor_id = nil
      self.loser_competitor_id = nil
      self.draw = true
    elsif home_goals > away_goals
      self.winner_competitor_id = home_competitor_id
      self.loser_competitor_id = away_competitor_id
      self.draw = true
    elsif away_goals > home_goals 
      self.winner_competitor_id = away_competitor_id
      self.loser_competitor_id = home_competitor_id
      self.draw = true
    end
  end
  
  def result_not_changed
    if (home_goals_was.present? && away_goals_was.present?) && (home_goals_changed? || away_goals_changed?)
      errors[:base] << I18n.t('activerecord.errors.models.tournament_match.attributes.base.result_cannot_be_changed')
    end
  end
end