class TournamentMatch < ActiveRecord::Base
  belongs_to :season, class_name: 'TournamentSeason'
  belongs_to :home_competitor, class_name: 'Competitor'
  belongs_to :away_competitor, class_name: 'Competitor'
  belongs_to :winner_competitor, class_name: 'Competitor'
  belongs_to :loser_competitor, class_name: 'Competitor'
  
  scope :for_competitor, ->(competitor_id) { where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor_id) }
  
  scope :for_competitors, ->(competitor_id, other_competitor_id) do
    where(
      %Q{
        (home_competitor_id = :competitor_id OR away_competitor_id = :competitor_id) AND 
        (home_competitor_id = :other_competitor_id OR away_competitor_id = :other_competitor_id)
      }, 
      competitor_id: competitor_id, other_competitor_id: other_competitor_id
    )
  end
  
  validates :season_id, presence: true
  validates :home_competitor_id, presence: true
  validates :away_competitor_id, presence: true
  validates :date, presence: true
  validate :goals_for_both_sides_or_both_blank
  validate :result_not_changed
  validate :results_for_current_matchday, if: 'home_goals.present? && away_goals.present?'
  validate :result_of_both_round_matches_is_not_a_draw, if: 'home_goals.present? && away_goals.present? && season.tournament.is_single_elimination? && season.tournament.with_second_leg?'
  
  attr_accessible :season_id, :round, :matchday, :home_competitor_id, :away_competitor_id, :home_goals, :away_goals, :date

  before_validation :set_winner_and_loser_or_draw
  
  def self.winner_of_two_matches(matches)
    competitor_goals = matches[0].home_goals + matches[1].away_goals
    other_competitor_goals = matches[0].away_goals + matches[1].home_goals
    
    if competitor_goals > other_competitor_goals
      matches[0].home_competitor_id
    elsif other_competitor_goals > competitor_goals
      matches[0].away_competitor_id
    elsif matches[1].away_goals > matches[0].away_goals
      matches[0].home_competitor_id
    elsif matches[0].away_goals > matches[1].away_goals
      matches[0].away_competitor_id
    else
      nil
    end
  end
  
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
  
  def goals_for_both_sides_or_both_blank
    if (home_goals.present? && away_goals.blank?) || (away_goals.present? && home_goals.blank?)
      errors[:base] << I18n.t('activerecord.errors.models.tournament_match.attributes.base.need_goals_for_both_sides')
    end
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
  
  def result_of_both_round_matches_is_not_a_draw
    first_match = season.matches.for_competitors(home_competitor_id, away_competitor_id).where(round: round, matchday: matchday - 1).first
    
    if first_match && TournamentMatch.winner_of_two_matches([first_match, self]).nil?
      errors[:base] << I18n.t('activerecord.errors.models.tournament_match.attributes.base.result_of_both_matches_cant_be_a_draw')
    end
  end
end