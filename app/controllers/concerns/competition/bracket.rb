module Competition
  module Bracket
    extend ActiveSupport::Concern
    
    def get_bracket_variables
      @winner_rounds = @season.winner_rounds
      @with_second_leg = @season.tournament.with_second_leg?
      @third_place_playoff = @season.tournament.third_place_playoff?
      @round_matches_index = {}
      @winner_rounds.times {|round| @round_matches_index[round + 1] = 0 }
      @matches = @season.elimination_stage_matches
    end
  end
end