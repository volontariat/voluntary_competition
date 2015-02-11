class TournamentSeasonRanking < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :season, class_name: 'TournamentSeason'
  belongs_to :competitor
  
  validates :season_id, presence: true
  validates :position, presence: true
  validates :competitor_id, presence: true, uniqueness: { scope: [:season_id, :matchday, :position] }
  
  attr_accessible :season_id, :matchday, :played, :position, :previous_position, :trend, :competitor_id
  attr_accessible :points, :wins, :draws, :losses, :goals_scored, :goals_allowed
  
  before_save :set_goal_differential
  
  def self.create_by_season(season)
    position = 1
    
    season.competitors.each do |competitor|
      season.rankings.create!(matchday: 1, position: position, previous_position: position, competitor_id: competitor.id)
      position += 1
    end
  end
  
  def self.create_by_competitor(competitor_id, matchday, season)
    ranking = season.rankings.where(matchday: matchday - 1, competitor_id: competitor_id).first
    
    season.rankings.create!(
      matchday: matchday, position: ranking.position, previous_position: ranking.position,
      trend: ranking.trend, competitor_id: competitor_id, points: ranking.points, wins: ranking.wins,
      draws: ranking.draws, losses: ranking.losses, goal_differential: ranking.goal_differential,
      goals_scored: ranking.goals_scored, goals_allowed: ranking.goals_allowed
    )
  end
  
  def consider_match(match)
    self.played = true
    points_for_match = match.points_for_competitor(competitor_id)
    self.points += points_for_match
    self.wins += {0 => 0, 1 => 0, 3 => 1}[points_for_match] 
    self.draws += {0 => 0, 1 => 1, 3 => 0}[points_for_match] 
    self.losses += {0 => 1, 1 => 0, 3 => 0}[points_for_match]
    goals = match.goals_for_competitor(competitor_id) 
    self.goals_scored += goals[0]
    self.goals_allowed += goals[1]
    self.goal_differential = goals_scored - goals_allowed
    save!
  end
  
  def matches
    played? ? matchday : matchday - 1
  end
  
  def goal_differential_formatted
    "#{goal_differential > 0 ? '+' : ''}#{goal_differential}"
  end
  
  def calculate_trend
    if position == previous_position
      self.trend = 0
    elsif position < previous_position
      self.trend = 1
    else
      self.trend = 2
    end
  end
  
  private
  
  def set_goal_differential
    self.goal_differential = goals_scored - goals_allowed
  end
end