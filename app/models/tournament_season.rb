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
  
  before_create :initialize_current_matchday
  
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
  
  def rounds
    if tournament.is_round_robin?
      tournament.competitors_limit % 2 == 0 ? tournament.competitors_limit - 1 : tournament.competitors_limit
    elsif tournament.is_single_elimination?
      working_matchdays = tournament.with_group_stage? ? matchdays - tournament.last_matchday_of_group_stage : matchdays
      tournament.with_second_leg? ? (working_matchdays + 1) / 2 : working_matchdays
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

  def generate_matches
    competitor_ids = competitors.map(&:id).shuffle
    matchdays_count = 0
    
    if tournament.is_round_robin?
      matchdays_count = generate_round_robin_matches(competitor_ids)
    elsif tournament.is_single_elimination? && tournament.with_group_stage?
      offset = 0
      
      tournament.groups_count.times do |group_number|
        matchdays_count = generate_round_robin_matches(competitor_ids[offset..(offset + tournament.competitors_per_group - 1)], group_number + 1)
        offset += tournament.competitors_per_group
      end
      
      matchdays_count += matchdays_count_for_elimination_stage(tournament.elimination_stage_competitors_count)
    elsif tournament.is_single_elimination?
      matchdays_count = generate_single_elimination_matches(competitor_ids)
    end
    
    tournament.update_attribute(:matchdays_per_season, matchdays_count)
    self.matchdays = matchdays_count
    save!
  end
  
  def initialize_rankings
    TournamentSeasonRanking.create_by_season(self)
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
    working_rankings = rankings.where(matchday: matchday, competitor_id: competitor_ids).group_by(&:competitor_id)
    
    working_matches.each do |match|
      working_rankings[match.home_competitor_id].each{|r| r.consider_match(match)}
      working_rankings[match.away_competitor_id].each{|r| r.consider_match(match)}
    end
    
    TournamentSeasonRanking.sort(self, matchday)
    groups = working_matches.map(&:group_number).uniq.sort
    groups.each{|group_number| TournamentSeasonRanking.sort(self, matchday, group_number) } if groups.any?
    
    matchday_played = if tournament.is_round_robin? || (tournament.with_group_stage? && matchday <= tournament.last_matchday_of_group_stage)
      rankings.where(matchday: matchday, played: false).none?
    elsif tournament.is_single_elimination?
      rankings.where(matchday: matchday, played: true).count == (matches.where(matchday: matchday).count * 2)
    end
    
    if matchday_played && matchday + 1 <= matchdays
      increment!(:current_matchday) 
      
      competitors.each do |competitor|
        TournamentSeasonRanking.create_by_competitor(competitor.id, current_matchday, self)
      end
      
      if tournament.is_single_elimination? && tournament.with_group_stage? && matchday == tournament.last_matchday_of_group_stage
        generate_single_elimination_matches_for_winners_and_losers
      elsif tournament.is_single_elimination? && (
        (tournament.with_second_leg? && matchday % 2 == 0) || !tournament.with_second_leg?
      ) && (
        !tournament.with_group_stage? || matchday > tournament.last_matchday_of_group_stage
      )
        generate_matches_for_next_round
      end
    end
    
    input_matches
  end
  
  def elimination_stage_matches
    hash = matches.for_elimination_stage(tournament).order('round ASC, matchday ASC, created_at ASC').includes(:home_competitor, :away_competitor).group_by(&:round)
    
    hash.each do |round, working_matches| 
      hash[round] = {} 
      
      working_matches.group_by(&:matchday).each do |matchday, matchday_matches|
        matchday = tournament.with_group_stage? ? matchday - tournament.last_matchday_of_group_stage : matchday
        
        hash[round][matchday] = matchday_matches
      end
    end
    
    hash
  end
  
  private
  
  def initialize_current_matchday
    self.current_matchday = 1 unless current_matchday.present?
  end
  
  def no_more_competitors_needed
    errors[:base] << I18n.t('tournament_seasons.activate.still_competitors_needed') if competitors_needed?
  end
  
  def generate_round_robin_matches(competitor_ids, group_number = nil)
    already_played_matchdays, first_leg_matchdays_count, primitive_matches = {}, 0, {}
    competitor_ids.each{|id| already_played_matchdays[id] ||= {} }
    combinations = TournamentMatch.combinations(competitor_ids)
    first_leg_matchdays_count = competitor_ids.length % 2 == 0 ? (competitor_ids.length - 1) : competitor_ids.length
    first_leg_matchdays_count.times do |matchday|
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
          group_number: group_number, matchday: matchday, home_competitor_id: home_competitor_id, away_competitor_id: away_competitor_id, date: Time.now
        )
        primitive_matches[matchday] ||= []
        primitive_matches[matchday] << [home_competitor_id, away_competitor_id]
        combinations.delete found_combination
        already_played_matchdays[competitor_id][matchday] = match_played_home
        already_played_matchdays[other_competitor_id][matchday] = match_played_home ? false : true
      end
    end
    
    generate_second_leg_matches(nil, primitive_matches, first_leg_matchdays_count) if tournament.with_second_leg?
    
    matchdays_count = tournament.with_second_leg? ? (first_leg_matchdays_count * 2) : first_leg_matchdays_count
  end
  
  def generate_single_elimination_matches(competitor_ids)
    already_played, primitive_matches = {}, {}
      
    competitor_ids.each do |competitor_id|
      next if already_played[competitor_id]
      
      other_competitor_id = competitor_ids.select{|id| id != competitor_id && !already_played[id]}.first
      
      next if other_competitor_id == nil
      
      matches.create!(
        round: 1, matchday: 1, home_competitor_id: competitor_id, away_competitor_id: other_competitor_id, date: Time.now
      )
      primitive_matches[1] ||= []
      primitive_matches[1] << [competitor_id, other_competitor_id] 
      already_played[competitor_id] = true
      already_played[other_competitor_id] = true
    end
    
    generate_second_leg_matches(1, primitive_matches, 1) if tournament.with_second_leg?
    
    matchdays_count_for_elimination_stage(competitor_ids.length)
  end
  
  def generate_second_leg_matches(round, primitive_matches, matchday_offset)
    primitive_matches.keys.sort.each do |matchday|
      primitive_matches[matchday].each do |match|
        working_matchday = matchday_offset + matchday
        matches.create!(
          round: round, matchday: working_matchday, home_competitor_id: match.last, away_competitor_id: match.first, date: Time.now
        )
      end
    end
  end
  
  def matchdays_count_for_elimination_stage(competitors_count)
    matchdays_count, competitors_left = 0, competitors_count
      
    begin
      matchdays_count += 1
      competitors_left = competitors_left / 2
    end while competitors_left > 1
    
    if tournament.with_second_leg?
      # - 1 because the final and third place playoff is only one match
      (matchdays_count * 2) - 1
    else
      matchdays_count
    end
  end
  
  def generate_single_elimination_matches_for_winners_and_losers
    primitive_matches = {}
    working_rankings = winners_and_losers_of_group_stage
    matchday = tournament.last_matchday_of_group_stage + 1
    
    [1, 0].each do |modulo_result|
      # 1.1 vs. 2.2, 3.1 vs. 4.2, 5.1 vs. 6.2 ...
      # 2.1 vs. 1.2, 4.1 vs. 3.2, 6.1 vs. 5.2 ...
      working_rankings.keys.sort.each do |group_number|
        next if group_number % 2 != modulo_result
        
        loser_group = modulo_result == 1 ? group_number + 1 : group_number - 1
        match = matches.create!(
          round: 1, matchday: matchday, date: Time.now,
          home_competitor_id: working_rankings[group_number][1].competitor_id, 
          away_competitor_id: working_rankings[loser_group][2].competitor_id 
        )
        primitive_matches[matchday] ||= []
        primitive_matches[matchday] << [match.home_competitor_id, match.away_competitor_id] 
      end
    end
    
    generate_second_leg_matches(1, primitive_matches, 1) if tournament.with_second_leg?
  end
  
  def winners_and_losers_of_group_stage
    working_rankings = rankings.where(matchday: tournament.last_matchday_of_group_stage).
                       where('group_number IS NOT NULL AND position IN(1,2)').
                       order('group_number ASC, position ASC').group_by(&:group_number)
    working_rankings.each {|group_number, rankings| working_rankings[group_number] = rankings.index_by(&:position) }
    working_rankings
  end
  
  def generate_matches_for_next_round
    primitive_matches, round = {}, nil
    
    (tournament.third_place_playoff? ? [true, false] : [true]).each do |is_winner|
      next unless is_winner || (is_winner == false && current_matchday == matchdays)
      
      competitor_ids, round = TournamentMatch.losers_or_winners_of_current_round(self, is_winner)
      
      begin
        match = matches.create!(
          round: round, matchday: current_matchday, home_competitor_id: competitor_ids.shift, away_competitor_id: competitor_ids.shift, date: Time.now
        )
        primitive_matches[current_matchday] ||= []
        primitive_matches[current_matchday] << [match.home_competitor_id, match.away_competitor_id] 
      end while competitor_ids.any?
    end
    
    generate_second_leg_matches(round, primitive_matches, 1) if tournament.with_second_leg? && current_matchday != matchdays
  end
end