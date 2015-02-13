class TournamentMatch < ActiveRecord::Base
  belongs_to :season, class_name: 'TournamentSeason'
  belongs_to :home_competitor, class_name: 'Competitor'
  belongs_to :away_competitor, class_name: 'Competitor'
  belongs_to :winner_competitor, class_name: 'Competitor'
  belongs_to :loser_competitor, class_name: 'Competitor'
  
  scope :for_competitor, ->(competitor_id) { where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor_id) }
  
  validates :season_id, presence: true
  validates :home_competitor_id, presence: true
  validates :away_competitor_id, presence: true
  validates :date, presence: true
  validate :result_not_changed
  validate :results_for_current_matchday, if: 'home_goals.present? && away_goals.present?'
  
  attr_accessible :season_id, :matchday, :home_competitor_id, :away_competitor_id, :home_goals, :away_goals, :date

  before_validation :set_winner_and_loser_or_draw
  
  def points_for_competitor(competitor_id)
    if draw
      1
    elsif winner_competitor_id == competitor_id
      3
    else
      0
    end
  end
  
  def goals_for_competitor(competitor_id)
    if home_competitor_id == competitor_id
      [home_goals, away_goals]
    else
      [away_goals, home_goals]
    end
  end
  
  private
  
  def set_winner_and_loser_or_draw
    return true if home_goals.nil? || home_goals == '' || away_goals.nil? || away_goals == '' 
    
    self.home_goals = home_goals.to_i
    self.away_goals = away_goals.to_i
    
    if home_goals == away_goals
      self.winner_competitor_id = nil
      self.loser_competitor_id = nil
      self.draw = true
    elsif home_goals > away_goals
      self.winner_competitor_id = home_competitor_id
      self.loser_competitor_id = away_competitor_id
      self.draw = false
    elsif away_goals > home_goals 
      self.winner_competitor_id = away_competitor_id
      self.loser_competitor_id = home_competitor_id
      self.draw = false
    end
    
    return true
  end
  
  def result_not_changed
    if (home_goals_was.present? && away_goals_was.present?) && (home_goals_changed? || away_goals_changed?)
      errors[:base] << I18n.t('activerecord.errors.models.tournament_match.attributes.base.result_cannot_be_changed')
    end
  end
  
  def results_for_current_matchday
    unless matchday == season.current_matchday
      errors[:base] << I18n.t(
        'activerecord.errors.models.tournament_match.attributes.base.results_only_for_current_matchday',
        matchday: season.current_matchday
      )
    end
  end
end