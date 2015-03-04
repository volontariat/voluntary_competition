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
    elsif tournament.is_elimination? && tournament.with_group_stage?
      offset = 0
      
      tournament.groups_count.times do |group_number|
        matchdays_count = generate_round_robin_matches(competitor_ids[offset..(offset + tournament.competitors_per_group - 1)], group_number + 1)
        offset += tournament.competitors_per_group
      end
      
      matchdays_count += matchdays_count_for_elimination_stage
    elsif tournament.is_elimination?
      matchdays_count = generate_elimination_matches(competitor_ids)
    end
    
    tournament.update_attribute(:matchdays_per_season, matchdays_count)
    self.matchdays = matchdays_count
    save!
  end
  
  def initialize_rankings
    TournamentSeasonRanking.create_by_season(self)
  end
  
  def winner_rounds
    working_matchdays = single_elimination_matchdays_count
    rounds = tournament.with_second_leg? ? (working_matchdays + 1) / 2 : working_matchdays
    
    tournament.is_single_elimination? ? rounds : rounds + 1
  end
  
  def loser_rounds
    ((winner_rounds - 2) * 2) + 1
  end
  
  def first_match_of_last_matchday
    matches.where(matchday: current_matchday - 1).first
  end
  
  def round_of_last_matchday
    first_match_of_last_matchday.round
  end
  
  def matches_of_round(of_winners_bracket, round)
    scope = matches.where(of_winners_bracket: of_winners_bracket, round: round)
    
    if tournament.with_second_leg?
      first_match_day = scope.order('matchday ASC').first.matchday
      scope = scope.where(matchday: first_match_day)
    end
    
    scope.order('created_at ASC')
  end
  
  def consider_matches(matches_param_value, matchday)
    already_played_competitor_ids = rankings.where(matchday: matchday, played: true).map(&:competitor_id)
    input_matches = TournamentMatch.update(matches_param_value.keys, matches_param_value.values)
    
    working_matches = input_matches.select do |m| 
      m.errors.empty? && (m.winner_competitor_id.present? || !m.draw.nil?) && !already_played_competitor_ids.include?(m.home_competitor_id)
    end
    
    return input_matches if working_matches.none?
    
    competitor_ids = working_matches.map{|m| [m.home_competitor_id, m.away_competitor_id]}.flatten
    #matchday = working_matches.first.matchday
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
    elsif tournament.is_elimination?
      rankings.where(matchday: matchday, played: true).count == (matches.where(matchday: matchday).count * 2)
    end
    
    if matchday_played && (
      matchday + 1 <= matchdays || (
        tournament.is_double_elimination? && !w_of_l_won_grand_finals_first_match_against_w_of_w?
      ) 
    )
      self.current_matchday += 1
      
      competitors.each do |competitor|
        TournamentSeasonRanking.create_by_competitor(competitor.id, current_matchday, self)
      end
      
      if matchday + 1 > matchdays
        first_grand_finals_match = input_matches.first
        
        if w_of_l_won_grand_finals_first_match_against_w_of_w_check?(first_grand_finals_match)
          self.matchdays += 1
          self.w_of_l_won_grand_finals_first_match_against_w_of_w = true
          first_grand_finals_match.create_second_leg_match
        else
          return input_matches
        end
      end
      
      save!
      
      return input_matches if w_of_l_won_grand_finals_first_match_against_w_of_w?
      
      if tournament.is_elimination? && tournament.with_group_stage? && matchday == tournament.last_matchday_of_group_stage
        generate_elimination_matches_for_winners_and_losers
      elsif tournament.is_elimination? && (
        (tournament.with_second_leg? && matchday % 2 == 0) || !tournament.with_second_leg?
      ) && (
        !tournament.with_group_stage? || matchday > tournament.last_matchday_of_group_stage
      )
        generate_matches_for_next_round
      end
    end
    
    input_matches
  end
  
  def w_of_l_won_grand_finals_first_match_against_w_of_w_check?(first_grand_finals_match)
    losers_finals_winner = TournamentMatch.winners_of_round(self, false, loser_rounds - 1).first
    first_grand_finals_match.winner_competitor_id == losers_finals_winner
  end
  
  def elimination_stage_matches
    round_matches_index = {}
    hash = matches.for_elimination_stage(tournament).order('of_winners_bracket DESC, round ASC, matchday ASC, created_at ASC').includes(:home_competitor, :away_competitor).group_by(&:of_winners_bracket)
    
    hash.each do |of_winners_bracket, of_winners_bracket_matches|
      hash[of_winners_bracket] = {}
      round_matches_index[of_winners_bracket] = {}
      (of_winners_bracket ? winner_rounds : loser_rounds).times {|round| round_matches_index[of_winners_bracket][round + 1] = 0 }
      of_winners_bracket_matches = of_winners_bracket_matches.group_by(&:round)
      
      of_winners_bracket_matches.keys.sort.each do |round|
        round_matches = of_winners_bracket_matches[round]
        hash[of_winners_bracket][round] = {}
        
        round_matches.group_by(&:elimination_stage_matchday).each {|matchday, matchday_matches| hash[of_winners_bracket][round][matchday] = matchday_matches }
      end
    end

    [hash, round_matches_index]
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
        primitive_matches[matchday] << [nil, nil, home_competitor_id, away_competitor_id]
        combinations.delete found_combination
        already_played_matchdays[competitor_id][matchday] = match_played_home
        already_played_matchdays[other_competitor_id][matchday] = match_played_home ? false : true
      end
    end
    
    generate_second_leg_matches(primitive_matches, first_leg_matchdays_count) if tournament.with_second_leg?
    
    matchdays_count = tournament.with_second_leg? ? (first_leg_matchdays_count * 2) : first_leg_matchdays_count
  end
  
  def generate_elimination_matches(competitor_ids)
    already_played, primitive_matches = {}, {}
      
    competitor_ids.each do |competitor_id|
      next if already_played[competitor_id]
      
      other_competitor_id = competitor_ids.select{|id| id != competitor_id && !already_played[id]}.first
      
      next if other_competitor_id == nil
      
      matches.create!(
        of_winners_bracket: true, round: 1, matchday: 1, home_competitor_id: competitor_id, away_competitor_id: other_competitor_id, date: Time.now
      )
      primitive_matches[1] ||= []
      primitive_matches[1] << [true, 1, competitor_id, other_competitor_id] 
      already_played[competitor_id] = true
      already_played[other_competitor_id] = true
    end
    
    generate_second_leg_matches(primitive_matches, 1) if tournament.with_second_leg?
    
    matchdays_count_for_elimination_stage
  end
  
  def generate_second_leg_matches(primitive_matches, matchday_offset)
    primitive_matches.keys.sort.each do |matchday|
      primitive_matches[matchday].each do |match|
        working_matchday = matchday_offset + matchday
        matches.create!(
          of_winners_bracket: match[0], round: match[1], matchday: working_matchday, home_competitor_id: match[3], away_competitor_id: match[2], date: Time.now
        )
      end
    end
  end
  
  def matchdays_count_for_elimination_stage
    if tournament.is_double_elimination?
      matchdays = (winner_rounds - 1) + (loser_rounds - 1)
      matchdays *= 2 if tournament.with_second_leg?
      matchdays += (w_of_l_won_grand_finals_first_match_against_w_of_w ? 2 : 1)
      matchdays
    else
      single_elimination_matchdays_count
    end
  end
  
  def single_elimination_matchdays_count
    matchdays_count, competitors_left = 0, tournament.elimination_stage_competitors_count
      
    begin
      matchdays_count += 1
      competitors_left = competitors_left / 2
    end while competitors_left > 1
    
    # - 1 because the final and third place playoff is only one match
    tournament.with_second_leg? ? (matchdays_count * 2) - 1 : matchdays_count
  end
  
  def generate_elimination_matches_for_winners_and_losers
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
          of_winners_bracket: true, round: 1, matchday: matchday, date: Time.now,
          home_competitor_id: working_rankings[group_number][1].competitor_id, 
          away_competitor_id: working_rankings[loser_group][2].competitor_id 
        )
        primitive_matches[matchday] ||= []
        primitive_matches[matchday] << [true, 1, match.home_competitor_id, match.away_competitor_id] 
      end
    end
    
    generate_second_leg_matches(primitive_matches, 1) if tournament.with_second_leg?
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
    last_round = first_match_of_last_matchday.round
    last_round_of_winners_bracket = first_match_of_last_matchday.of_winners_bracket
    
    (tournament.third_place_playoff? ? [true, false] : [true]).each do |is_winner|
      next unless is_winner || (is_winner == false && current_matchday == matchdays)
      
      if !is_winner
        [[true, last_round, false, nil, last_round + 1, current_matchday]]
      elsif tournament.is_single_elimination?
        [[true, last_round, true, true, last_round + 1, current_matchday]]
      else
        if last_round_of_winners_bracket && last_round == 1
          # after W1
          #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 1"
          [
            [true, last_round, true, true, last_round + 1, current_matchday + 1], [true, last_round, false, false, last_round, current_matchday]
          ]
        elsif last_round_of_winners_bracket && last_round != winner_rounds - 1
          if last_round % 2 == 0
            # e.g. after W2
            #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 2"
            [
              [true, last_round, true, true, last_round + 1, current_matchday + 2], 
              [
                [true, last_round, false, false, last_round, current_matchday], 
                [false, last_round - 1, true, false, last_round, current_matchday]
              ]
            ]
          else
            # e.g. after W3
            #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 3"
            list = []
            
            if matches.where(of_winners_bracket: true, round: last_round).count > 1
              list << [true, last_round, true, true, last_round + 1, current_matchday + 2]
            end
            
            list << [
              [true, last_round, false, false, last_round + 1, current_matchday], 
              [false, last_round, true, false, last_round + 1, current_matchday]
            ]
          end
        elsif last_round_of_winners_bracket
          # after winner's finals wait for loser's finals
          #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 4"
          
          
          [
            [
              [true, last_round, false, false, loser_rounds - 1, current_matchday],
              #[false, last_round - 1, true, false, last_round, current_matchday]
              [false, loser_rounds - 2, true, false, loser_rounds - 1, current_matchday]
            ]
          ]
          
          
          
        elsif last_round != loser_rounds - 1
          if last_round % 2 != 0
            #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 5"
            # e.g. after L1, L3
            []
          else
            # e.g. after L2
            #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 6"
            [[false, last_round, true, false, last_round + 1, current_matchday]]
          end
        else
          # after losers finals transformation to grand finals
          #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 7"
          [
            [
              [true, winner_rounds - 1, true, true, winner_rounds, current_matchday], 
              [false, last_round, true, true, winner_rounds, current_matchday]
            ]
          ]
        end
      end.each do |of_winners_bracket_and_winner_or_loser|
        if of_winners_bracket_and_winner_or_loser[0].is_a? Array
          competitor_ids = [
            TournamentMatch.losers_or_winners_of_round(
              self, of_winners_bracket_and_winner_or_loser[0][0], 
              of_winners_bracket_and_winner_or_loser[0][1], of_winners_bracket_and_winner_or_loser[0][2]
            ),
            TournamentMatch.losers_or_winners_of_round(
              self, of_winners_bracket_and_winner_or_loser[1][0], 
              of_winners_bracket_and_winner_or_loser[1][1], of_winners_bracket_and_winner_or_loser[1][2]
            )
          ]
          to_of_winners_bracket = of_winners_bracket_and_winner_or_loser[0][3]
          next_round = of_winners_bracket_and_winner_or_loser[0][4]
          matchday = of_winners_bracket_and_winner_or_loser[0][5]
          
          begin
            match = matches.create!(
              of_winners_bracket: to_of_winners_bracket, round: next_round, matchday: matchday, 
              home_competitor_id: competitor_ids[0].shift, away_competitor_id: competitor_ids[1].shift, date: Time.now
            )
            #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 1 match: #{{ to_of_winners_bracket: to_of_winners_bracket, next_round: next_round, matchday: matchday, match_id: match.id }}"
            primitive_matches[matchday] ||= []
            primitive_matches[matchday] << [to_of_winners_bracket, next_round, match.home_competitor_id, match.away_competitor_id] 
          end while competitor_ids[0].any?
        else
          from_winners_bracket, round, is_winner, to_of_winners_bracket, next_round, matchday = of_winners_bracket_and_winner_or_loser
          competitor_ids = TournamentMatch.losers_or_winners_of_round(self, from_winners_bracket, round, is_winner)
          
          begin
            match = matches.create!(
              of_winners_bracket: to_of_winners_bracket, round: next_round, matchday: matchday, home_competitor_id: competitor_ids.shift, away_competitor_id: competitor_ids.shift, date: Time.now
            )
            #puts "After #{(last_round_of_winners_bracket ? 'W' : 'L')}-#{last_round} case 2 match: #{{ to_of_winners_bracket: to_of_winners_bracket, next_round: next_round, matchday: matchday, match_id: match.id }}"
            primitive_matches[matchday] ||= []
            primitive_matches[matchday] << [to_of_winners_bracket, next_round, match.home_competitor_id, match.away_competitor_id] 
          end while competitor_ids.any?
        end
      end
    end
    
    primitive_matches.each {|matchday| primitive_matches.delete(matchday) if matchday == matchdays }
    
    generate_second_leg_matches(primitive_matches, 1) if primitive_matches.any? && tournament.with_second_leg? && current_matchday != matchdays
  end
end