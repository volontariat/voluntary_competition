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
  
  scope :rated, -> { where('winner_competitor_id IS NOT NULL OR draw IS NOT NULL') }
  
  scope :for_elimination_stage, ->(tournament) { where('matchday >= ?', tournament.with_group_stage? ? tournament.last_matchday_of_group_stage + 1 : 1) }
  
  validates :season_id, presence: true
  validates :home_competitor_id, presence: true
  validates :away_competitor_id, presence: true
  validates :date, presence: true
  validate :goals_for_both_sides_or_both_blank
  validate :result_not_changed
  validate :results_for_current_matchday, if: 'home_goals.present? && away_goals.present?'
  validate :result_of_both_round_matches_is_not_a_draw, if: 'home_goals.present? && away_goals.present? && season.tournament.is_elimination? && season.tournament.with_second_leg?'
  
  attr_accessible :season_id, :group_number, :of_winners_bracket, :round, :matchday, :home_competitor_id, :away_competitor_id, :home_goals, :away_goals, :date

  before_validation :set_winner_and_loser_or_draw
  
  def self.combinations(competitor_ids)
    list, already_played_competitor_ids = [], {}
    
    competitor_ids.each do |competitor_id|
      already_played_competitor_ids[competitor_id] ||= []
      working_competitor_ids = competitor_ids.select{|id| id != competitor_id && !already_played_competitor_ids[competitor_id].include?(id)}.shuffle
      
      working_competitor_ids.each do |other_competitor_id|
        already_played_competitor_ids[other_competitor_id] ||= []
        already_played_competitor_ids[competitor_id] << other_competitor_id
        already_played_competitor_ids[other_competitor_id] << competitor_id
        list << [competitor_id, other_competitor_id]
      end
    end
    
    list.shuffle
  end
  
  def self.winners_of_round(season, of_winners_bracket, round)
    losers_or_winners_of_round(season, of_winners_bracket, round, true)
  end
  
  def self.losers_or_winners_of_round(season, of_winners_bracket, round, is_winner)
    matches = season.matches_of_round(of_winners_bracket, round)
    
    competitor_ids = if season.tournament.with_second_leg?
      ids = []
      
      matches.each do |first_match|
        second_match = season.matches.for_competitors(first_match.home_competitor_id, first_match.away_competitor_id).where(matchday: season.current_matchday - 1).first
        winner = winner_of_two_matches([first_match, second_match])
        competitor_id = is_winner ? winner : first_match.other_competitor_id(winner)
        ids << competitor_id
      end
      
      ids
    else 
      matches = matches.to_a
      is_winner ? matches.map(&:winner_competitor_id) : matches.map(&:loser_competitor_id)
    end
    
    competitor_ids
  end
  
  def self.direct_comparison(matches)
    matches = matches.select{|m| m.winner_competitor_id.present? || m.draw == true }
    
    if matches.any?  
      matches.length == 1 ? matches.first.winner_competitor_id : TournamentMatch.winner_of_two_matches(matches)
    else
      -1
    end
  end
  
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
  
  def other_competitor_id(competitor_id)
    home_competitor_id == competitor_id ? away_competitor_id : home_competitor_id
  end
  
  def elimination_stage_matchday
    season.tournament.with_group_stage? ? matchday - season.tournament.last_matchday_of_group_stage : matchday
  end
  
  def create_second_leg_match
    season.matches.create!(
      of_winners_bracket: of_winners_bracket, round: round, matchday: matchday + 1, home_competitor_id: away_competitor_id, 
      away_competitor_id: home_competitor_id, date: Time.now
    )
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