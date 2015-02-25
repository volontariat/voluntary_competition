module Competition
  module Bracket
    extend ActiveSupport::Concern
    
    def get_bracket_variables
      @rounds = @season.rounds
      @with_second_leg = @season.tournament.with_second_leg?
      @round_matches_index = {}
      @rounds.times {|round| @round_matches_index[round + 1] = 0 }
      @matches = @season.matches.order('round ASC, matchday ASC, created_at ASC').includes(:home_competitor, :away_competitor).group_by(&:round)
      @matches.each {|round, matches| @matches[round] = matches.group_by(&:matchday) }
    end
  end
end