# -*- encoding : utf-8 -*-
require 'spec_helper'

describe 'competition/tournament_seasons/_bracket.html.erb' do
  let(:is_single_elimination) { true }
  let(:is_double_elimination) { false }
  let(:competitors_limit) { 4 }
  let(:winner_rounds) { 2 }
  let(:with_second_leg) { false }
  let(:third_place_playoff) { false }
  let(:matchdays) { winner_rounds }
  let(:preview) { false }
  
  before :each do
    @season = TournamentSeason.new
    @season.id = 1
    @season.state = 'active'
    @season.matchdays = matchdays
    assign :season, @season
    assign :can_update_season, false
    assign :is_single_elimination, is_single_elimination
    assign :is_double_elimination, is_double_elimination
    assign :winner_rounds, winner_rounds
    assign :with_second_leg, with_second_leg
    assign :third_place_playoff, third_place_playoff
    matches = load_ruby_fixture("#{fixture_path}_matches.txt")
    assign :matches, matches
    
    round_matches_index = {}
    
    matches.each do |of_winners_bracket, of_winners_bracket_matches|
      round_matches_index[of_winners_bracket] ||= {}
      of_winners_bracket_matches.keys.each {|round| round_matches_index[of_winners_bracket][round] = 0 }
    end
    
    assign :round_matches_index, round_matches_index
    
    render partial: 'competition/tournament_seasons/bracket'
    
    compare_texts rendered, "#{fixture_path}.html"
  end
  
  context 'tournament is single elimination' do
    context 'with 4 competitors' do
      let(:with_second_leg_matchdays) { 3 }
      
      it_behaves_like 'a tournament season bracket'
    end
    
    context 'with 8 competitors' do
      let(:competitors_limit) { 8 }
      let(:winner_rounds) { 3 }
      let(:with_second_leg_matchdays) { 5 }
      
      it_behaves_like 'a tournament season bracket'
    end
    
    context 'with 16 competitors' do
      let(:competitors_limit) { 16 }
      let(:winner_rounds) { 4 }
      let(:with_second_leg_matchdays) { 7 }
      
      it_behaves_like 'a tournament season bracket'
    end
  end
end