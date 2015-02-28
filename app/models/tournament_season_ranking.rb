class TournamentSeasonRanking < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :season, class_name: 'TournamentSeason'
  belongs_to :competitor
  
  validates :season_id, presence: true
  validates :matchday, presence: true
  validates :position, presence: true
  validates :competitor_id, presence: true, uniqueness: { scope: [:season_id, :group_number, :matchday, :position] }
  
  attr_accessible :season_id, :group_number, :matchday, :played, :matches, :position, :previous_position, :trend, :competitor_id
  attr_accessible :points, :wins, :draws, :losses, :goals_scored, :goals_allowed
  
  before_save :set_goal_differential
  
  def self.create_by_season(season)
    position, group_positions = 1, {}
    
    season.competitors.each do |competitor|
      match = season.matches.for_competitor(competitor.id).where(matchday: 1).first
      played = match.present? ? false : true
      
      group_number = if match.present?
        match.group_number
      elsif season.tournament.with_group_stage?
        season.matches.for_competitor(competitor.id).where('group_number IS NOT NULL').first.group_number
      end
      
      season.rankings.create!(matchday: 1, played: played, position: position, previous_position: position, competitor_id: competitor.id)
      
      if season.tournament.with_group_stage?
        group_positions[group_number] ||= 1
        season.rankings.create!(
          matchday: 1, group_number: group_number, played: played, position: group_positions[group_number], 
          previous_position: group_positions[group_number], competitor_id: competitor.id
        )
        group_positions[group_number] += 1
      end
      
      position += 1
    end
  end
  
  def self.create_by_competitor(competitor_id, matchday, season)
    played = if season.tournament.is_round_robin? || (season.tournament.with_group_stage? && matchday <= season.tournament.last_matchday_of_group_stage)
      season.matches.for_competitor(competitor_id).where(matchday: matchday).any? ? false : true
    elsif season.tournament.is_single_elimination?
      false
    end
    
    2.times do |time|
      rankings = season.rankings.where(matchday: matchday - 1, competitor_id: competitor_id)
      rankings = time == 0 ? rankings.where('group_number IS NULL') : rankings.where('group_number IS NOT NULL')
      
      break unless time == 0 || (time == 1 && season.tournament.with_group_stage? && matchday <= season.tournament.last_matchday_of_group_stage)
        
      ranking = rankings.first
      season.rankings.create!(
        group_number: time == 0 ? nil : ranking.group_number, matchday: matchday, played: played, matches: ranking.matches, position: ranking.position, 
        previous_position: ranking.position, trend: ranking.trend, competitor_id: competitor_id, points: ranking.points, wins: ranking.wins,
        draws: ranking.draws, losses: ranking.losses, goals_scored: ranking.goals_scored, goals_allowed: ranking.goals_allowed
      )
    end
  end
  
  def self.sort(season, matchday, group_number = nil)
    working_rankings = season.rankings.where(matchday: matchday, group_number: group_number)
    
    if season.tournament.is_round_robin? || (!group_number.nil? && season.tournament.with_group_stage? && matchday <= season.tournament.last_matchday_of_group_stage)
      working_rankings = working_rankings.order('points DESC, goal_differential DESC, goals_scored DESC').to_a
    else
      working_rankings = working_rankings.order('points DESC, matches DESC, goal_differential DESC, goals_scored DESC').to_a
    end
    
    position, positions, ties = 1, {}, {}
    
    working_rankings.each do |r1|
      tie_key = ''
      
      is_tie = if season.tournament.is_round_robin? || (!group_number.nil? && season.tournament.with_group_stage? && matchday <= season.tournament.last_matchday_of_group_stage)
        tie_key = "#{r1.points},#{r1.goal_differential},#{r1.goals_scored}"
        working_rankings.select do |r2| 
          r2.id != r1.id && r2.points == r1.points && r2.goal_differential == r1.goal_differential && r2.goals_scored == r1.goals_scored
        end.any?
      else
        tie_key = "#{r1.points},#{r1.matches},#{r1.goal_differential},#{r1.goals_scored}"
        working_rankings.select do |r2| 
          r2.id != r1.id && r2.points == r1.points && r2.matches == r1.matches && r2.goal_differential == r1.goal_differential && r2.goals_scored == r1.goals_scored
        end.any?
      end
      
      if is_tie
        ties[tie_key] ||= { positions: [], rankings: [] }
        ties[tie_key][:positions] << position
        ties[tie_key][:rankings] << r1
      else
        positions[position] = r1
      end
      
      position += 1
    end
    
    positions.merge!(resolve_ties(season, ties)) unless ties.empty?
    
    positions.each do |position, ranking|
      ranking.position = position
      ranking.calculate_trend
      ranking.save!
    end
  end
  
  def self.resolve_ties(season, ties)
    positions = {}
    
    ties.each do |tie_key, hash|
      combinations = TournamentMatch.combinations(hash[:rankings].map(&:competitor_id))
      rankings = []
      
      matches = combinations.map{|c| TournamentMatch.rated.for_competitors(*c) }.flatten
      
      matches.each do |match|
        # points DESC, goal_differential DESC, goals_scored DESC
        [match.home_competitor_id, match.away_competitor_id].each do |competitor_id|
          ranking_index = rankings.find_index { |r| r[:competitor_id] == competitor_id }
          
          if ranking_index.nil?
            rankings << { competitor_id: competitor_id, points: 0, goal_differential: 0, goals_scored: 0, goals_allowed: 0 }
            ranking_index = rankings.find_index { |r| r[:competitor_id] == competitor_id }
          end
          
          goals = match.goals_for_competitor(competitor_id) 
          rankings[ranking_index][:goals_scored] += goals[0]
          rankings[ranking_index][:goals_allowed] += goals[1]
          rankings[ranking_index][:goal_differential] = rankings[ranking_index][:goals_scored] - rankings[ranking_index][:goals_allowed]
          rankings[ranking_index][:points] += match.points_for_competitor(competitor_id)
        end
      end
      
      # set winner and loser of combinations
      direct_comparisons = {}
      
      combinations.each do |combination|
        winner_competitor_id = TournamentMatch.direct_comparison(
          matches.select{|m| combination.include?(m.home_competitor_id) && combination.include?(m.away_competitor_id)}
        )
        
        next if winner_competitor_id == -1
        
        combination.each do |competitor_id|
          other_competitor_id = combination.select{|id| id != competitor_id }.first
          direct_comparisons[competitor_id] ||= {}
          direct_comparisons[competitor_id][other_competitor_id] = winner_competitor_id.nil? || winner_competitor_id != competitor_id ? 0 : 1
        end
      end
       
      # consider 0:0 for competitors of combinations without match(es)
      combinations.each do |combination|
        next if matches.select{|m| combination.include?(m.home_competitor_id) && combination.include?(m.away_competitor_id)}.any?  
        
        combination.each do |competitor_id|
          ranking_index = rankings.find_index { |r| r[:competitor_id] == competitor_id }
            
          if ranking_index.nil?
            rankings << { competitor_id: competitor_id, points: 0, goal_differential: 0, goals_scored: 0, goals_allowed: 0 }
            ranking_index = rankings.find_index { |r| r[:competitor_id] == competitor_id }
          end
           
          other_competitor_id = combination.select{|id| id != competitor_id }.first
          rankings[ranking_index][:not_played_competitors] ||= []
          rankings[ranking_index][:not_played_competitors] << other_competitor_id   
          rankings[ranking_index][:points] += 1
        end
      end
      
      ::VoluntaryCompetition::Sorter.new(rankings, direct_comparisons).sort.each do |ranking|
        positions[hash[:positions].shift] = hash[:rankings].select{|r| r.competitor_id == ranking[:competitor_id] }.first
      end
    end
    
    positions
  end
  
  def consider_match(match)
    self.played = true
    self.matches += 1
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