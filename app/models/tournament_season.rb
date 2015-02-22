class TournamentSeason < ActiveRecord::Base
  include Applicat::Mvc::Model::Resource::Base
  
  belongs_to :tournament
  
  has_many :participations, class_name: 'TournamentSeasonParticipation', foreign_key: 'season_id', dependent: :destroy
  has_many :accepted_participations, -> { where "tournament_season_participations.state = 'accepted'" }, class_name: 'TournamentSeasonParticipation', foreign_key: 'season_id'
  has_many :competitors, foreign_key: 'season_id', through: :accepted_participations
  has_many :rankings, class_name: 'TournamentSeasonRanking', foreign_key: 'season_id'
  has_many :matches, class_name: 'TournamentMatch', foreign_key: 'season_id'
  
  validates :tournament_id, presence: true
  
  attr_accessible :name
  
  state_machine :state, initial: :looking_for_competitors do
    event :activate do
      transition looking_for_competitors: :active
    end
    
    state :active do
      validate :no_more_competitors_needed
    end
    
    after_transition looking_for_competitors: :active do |season, transition|
      season.generate_matches
      season.initialize_rankings
    end
  end
  
  def competitors_needed?
    if tournament.competitors_limit - participations.accepted.count > 0
      true
    else
      false
    end
  end
  
  def create_participations_by_competitor_ids(competitor_ids, user_id)
    working_errors = []
    
    competitor_ids.each do |competitor_id|
      season_participation = participations.new
      season_participation.competitor_id = competitor_id
      season_participation.user_id = user_id
      season_participation.save
      
      unless season_participation.persisted?
        working_errors = season_participation.errors.full_messages.join('. ')
        
        break
      end
    end
    
    working_errors
  end

  def consider_matches(matches_param_value, matchday)
    already_played_competitor_ids = rankings.where(matchday: matchday, played: true).map(&:competitor_id)
    input_matches = TournamentMatch.update(matches_param_value.keys, matches_param_value.values)
    
    working_matches = input_matches.select do |m| 
      m.errors.empty? && (m.winner_competitor_id.present? || !m.draw.nil?) && !already_played_competitor_ids.include?(m.home_competitor_id)
    end
    
    return input_matches if working_matches.none?
    
    competitor_ids = working_matches.map{|m| [m.home_competitor_id, m.away_competitor_id]}.flatten
    matchday = working_matches.first.matchday
    working_rankings = rankings.where(matchday: matchday, competitor_id: competitor_ids).index_by(&:competitor_id)
    
    working_matches.each do |match|
      working_rankings[match.home_competitor_id].consider_match(match)
      working_rankings[match.away_competitor_id].consider_match(match)
    end
    
    position = 1
    
    rankings.where(matchday: matchday).order('points DESC, goal_differential DESC, goals_scored DESC').each do |ranking|
      ranking.position = position
      ranking.calculate_trend
      ranking.save!
      
      position += 1
    end
    
    if rankings.where(matchday: matchday, played: false).none? && matchday + 1 <= matchdays
      increment!(:current_matchday) 
      
      competitors.each do |competitor|
        TournamentSeasonRanking.create_by_competitor(competitor.id, current_matchday, self)
      end
    end
    
    input_matches
  end
    
  def initialize_rankings
    TournamentSeasonRanking.create_by_season(self)
  end
  
  def generate_matches
    already_played_matchdays, already_played_competitor_ids, combinations, primitive_matches = {}, {}, [], {}
    competitor_ids = competitors.map(&:id).shuffle
    
    competitor_ids.each do |competitor_id|
      already_played_competitor_ids[competitor_id] ||= []
      already_played_matchdays[competitor_id] ||= {}
      working_competitor_ids = competitors.map(&:id).select{|id| id != competitor_id && !already_played_competitor_ids[competitor_id].include?(id)}.shuffle
      
      working_competitor_ids.each do |other_competitor_id|
        already_played_competitor_ids[other_competitor_id] ||= []
        already_played_competitor_ids[competitor_id] << other_competitor_id
        already_played_competitor_ids[other_competitor_id] << competitor_id
        combinations << [competitor_id, other_competitor_id]
      end
    end
    
    combinations.shuffle!
    rounds = competitors.length % 2 == 0 ? (competitors.length - 1) : competitors.length

    rounds.times do |matchday|
      matchday += 1
      
      competitor_ids.each do |competitor_id|
        next if already_played_matchdays[competitor_id].has_key? matchday
        
        last_match_played_home = already_played_matchdays[competitor_id][matchday - 1]
        match_played_home = last_match_played_home.nil? || !last_match_played_home ? true : false
        
        competitor_combinations = combinations.select do |combination|
          combination.include?(competitor_id) && !already_played_matchdays[combination.select{|id| id != competitor_id }.first].has_key?(matchday)
        end
        
        found_combination = nil
        
        competitor_combinations.each do |combination| 
          other_competitor_id = combination.select{|id| id != competitor_id }.first
          other_competitor_played_last_matched_home = already_played_matchdays[other_competitor_id][matchday - 1]
          
          if other_competitor_played_last_matched_home.nil? || other_competitor_played_last_matched_home == match_played_home
            found_combination = combination
            break
          end
        end
        
        if found_combination.nil? && !last_match_played_home.nil? && competitor_combinations.none?
          # bye
          next
        elsif found_combination.nil?
          match_played_home = match_played_home ? false : true
          
          competitor_combinations.each do |combination| 
            other_competitor_id = combination.select{|id| id != competitor_id }.first
            other_competitor_played_last_matched_home = already_played_matchdays[other_competitor_id][matchday - 1]
            
            if other_competitor_played_last_matched_home.nil? || other_competitor_played_last_matched_home == match_played_home
              found_combination = combination
              break
            end
          end

          if found_combination.nil?
            # bye
            next
          end 
        end
        
        other_competitor_id = found_combination.select{|id| id != competitor_id }.first
        home_competitor_id, away_competitor_id = match_played_home ? [competitor_id, other_competitor_id] : [other_competitor_id, competitor_id]
        matches.create!(
          matchday: matchday, home_competitor_id: home_competitor_id, away_competitor_id: away_competitor_id, date: Time.now
        )
        primitive_matches[matchday] ||= []
        primitive_matches[matchday] << [home_competitor_id, away_competitor_id]
        combinations.delete found_combination
        already_played_matchdays[competitor_id][matchday] = match_played_home
        already_played_matchdays[other_competitor_id][matchday] = match_played_home ? false : true
      end
    end
    
    if tournament.with_second_leg?
      primitive_matches.keys.sort.each do |matchday|
        primitive_matches[matchday].each do |match|
          matches.create!(
            matchday: rounds + matchday, home_competitor_id: match.last, away_competitor_id: match.first, date: Time.now
          )
        end
      end
    end
    
    rounds = tournament.with_second_leg? ? (rounds * 2) : rounds
    tournament.update_attribute(:matchdays_per_season, rounds)
    self.matchdays = rounds; self.current_matchday = 1; save!
  end
  
  private
  
  def no_more_competitors_needed
    errors[:base] << I18n.t('tournament_seasons.activate.still_competitors_needed') if competitors_needed?
  end
end