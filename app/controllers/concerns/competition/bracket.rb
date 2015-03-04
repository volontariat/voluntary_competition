module Competition
  module Bracket
    extend ActiveSupport::Concern
    
    def get_bracket_variables
      @is_single_elimination = @season.tournament.is_single_elimination?
      @is_double_elimination = @season.tournament.is_double_elimination?
      @winner_rounds = @season.winner_rounds
      @loser_rounds = @season.loser_rounds
      @with_second_leg = @season.tournament.with_second_leg?
      @third_place_playoff = @season.tournament.third_place_playoff?
      @matches, @round_matches_index = @season.elimination_stage_matches
    end
  end
end