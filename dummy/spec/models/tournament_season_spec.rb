require 'spec_helper'

def expect_season_fixtures(fixture_path)
  fixtures = load_ruby_fixture fixture_path
  fixtures = [fixtures] unless fixtures.is_a? Array
  
  fixtures.each_with_index do |matchday_fixture, index|
    matchday_fixture = load_ruby_fixture(fixture_path)[index] if matchday_fixture[:reload_fixture]
    
    @season.consider_matches(*matchday_fixture[:results])
    @season.reload
    
    expect(@season.current_matchday).to be == matchday_fixture[:current_matchday_after_results]
    
    if matchday_fixture.has_key? :number_of_matches_for_current_matchday
      @matches = @season.matches.where(matchday: matchday_fixture[:current_matchday_after_results]).to_a
      expect(@matches.length).to be == matchday_fixture[:number_of_matches_for_current_matchday]
    end
    
    compare_rankings(matchday_fixture[:rankings]) if matchday_fixture.has_key? :rankings
  end
end

def compare_rankings(expected_rankings)
  expected_rankings.each do |competitor_id, matchdays|
    matchdays.each do |matchday, ranking_attributes|
      ranking = @season.rankings.where(matchday: matchday, competitor_id: competitor_id).first
      
      ranking_attributes.each do |attribute, value|
        message = "#{@hash[competitor_id]}.#{attribute} on day #{matchday} got #{ranking.send(attribute).inspect} but expected #{value.inspect}"
        
        if value.is_a? Array
          expect(value.include?(ranking.send(attribute))).to be_truthy, message
        else
          expect(ranking.send(attribute)).to be == value, message
        end
      end
    end
  end
end

describe TournamentSeason do
  describe '#competitors_needed?' do
    before :each do
      @tournament = FactoryGirl.create(:tournament, competitors_limit: 1)
    end
  
    context 'competitors needed' do
      it 'returns true' do
        expect(@tournament.current_season.competitors_needed?).to be_truthy
      end
    end
    
    context 'no competitors needed' do
      context 'new_and_already_joined_competitors_count option is blank' do
        it 'returns the following message' do
          FactoryGirl.create(
            :tournament_season_participation, season: @tournament.current_season, 
            competitor: FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type)
          ).accept!
          
          expect(@tournament.current_season.competitors_needed?).to be_falsey
        end
      end
    end
  end
  
  describe '#create_participations_by_competitor_ids' do
    it 'does what the name says' do
      @tournament = FactoryGirl.create(:tournament, competitors_limit: 1)
      competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type)
      @tournament.current_season.create_participations_by_competitor_ids([competitor.id], competitor.user_id)
      
      expect(@tournament.current_season.participations.where(competitor_id: competitor.id).count).to be == 1
    end
  end
  
  describe '#generate_matches' do
    let(:system_type) { 0 }
    let(:competitors_limit) { 4 }
    let(:with_second_leg) { false }
    
    before :each do
      user = FactoryGirl.create(:user)
      @tournament = FactoryGirl.create(
        :tournament, system_type: system_type, competitors_limit: competitors_limit, with_second_leg: with_second_leg, user: user
      )
      @season = @tournament.current_season
      @denied_competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type)
      FactoryGirl.create(:tournament_season_participation, season: @season, competitor: @denied_competitor).deny!
      @accepted_competitors = []
      
      competitors_limit.times do
        competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
        @accepted_competitors << competitor
        FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
      end
    end
    
    context 'tournament is round-robin' do
      context 'without second leg' do
        context 'with even competitors' do
          it 'generates all possible matches between the accepted competitors' do
            expect(@season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: @denied_competitor.id).count).to be == 0
            
            @accepted_competitors.each do |competitor|
              matches = @season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor.id).order('matchday ASC').to_a
              expect(matches.map(&:matchday)).to be == [1, 2, 3]
              #expect([[true, false, true], [false, true, false]].include?(matches.map{|m| m.home_competitor_id == competitor.id })).to be_truthy
            end
            
            expect(@season.matchdays).to be == 3
          end
        end
        
        context 'with odd competitors' do
          let(:competitors_limit) { 3 }
          
          it 'also works with a uneven competitors - bye' do
            @accepted_competitors.each do |competitor|
              matches = @season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor.id).order('matchday ASC').to_a
              expect([[1, 3], [1, 2], [2, 3]].include?(matches.map(&:matchday))).to be_truthy
              expect([[true, false], [false, true]].include?(matches.map{|m| m.home_competitor_id == competitor.id })).to be_truthy
            end
            
            expect(@season.matchdays).to be == 3
          end
        end
      end
      
      context 'with second leg' do
        let(:with_second_leg) { true }
        
        it 'generates all possible matches between the accepted competitors with second leg' do
          expect(@season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: @denied_competitor.id).count).to be == 0
          
          @accepted_competitors.each do |competitor|
            matches = @season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor.id).order('matchday ASC').to_a
            expect(matches.map(&:matchday)).to be == [1, 2, 3, 4, 5, 6]
            #expect([[true, false, true, false, true, false], [false, true, false, true, false, true]].include?(matches.map{|m| m.home_competitor_id == competitor.id })).to be_truthy
          end
          
          expect(@season.matchdays).to be == 6
        end
      end
    end
    
    context 'tournament is single elimination' do
      let(:system_type) { 1 }
      
      context 'without second leg' do
        it 'generates 1 first round match for each competitor' do
          expect(@season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: @denied_competitor.id).count).to be == 0
          
          @accepted_competitors.each do |competitor|
            matches = @season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor.id).order('matchday ASC').to_a
            expect(matches.map(&:matchday)).to be == [1]
            #expect([[true, false, true, false, true, false], [false, true, false, true, false, true]].include?(matches.map{|m| m.home_competitor_id == competitor.id })).to be_truthy
          end
          
          expect(@season.matchdays).to be == 2
        end
      end
      
      context 'with second leg' do
        let(:with_second_leg) { true }
        
        it 'generates 2 first round matches for each competitor' do
          expect(@season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: @denied_competitor.id).count).to be == 0
          
          @accepted_competitors.each do |competitor|
            matches = @season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor.id).order('matchday ASC').to_a
            expect(matches.map(&:matchday)).to be == [1, 2]
            #expect([[true, false, true, false, true, false], [false, true, false, true, false, true]].include?(matches.map{|m| m.home_competitor_id == competitor.id })).to be_truthy
          end
          
          expect(@season.matchdays).to be == 3
        end
      end
    end
  end
  
  describe '#consider_matches' do
    let(:system_type) { 0 }
    let(:competitors_limit) { 4 }
    let(:with_second_leg) { false }
    
    before :each do
      @tournament = FactoryGirl.create(:tournament, system_type: system_type, competitors_limit: competitors_limit, with_second_leg: with_second_leg)
      @season = @tournament.current_season
      user = FactoryGirl.create(:user)
      
      competitors_limit.times do
        competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
        FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
      end
      
      @matches = @season.matches.where(matchday: 1)
      @first_matchday_matches = @matches
      @hash = {}
      @matches.each_with_index {|match, index| @hash.merge!(match.home_competitor_id => "#{index}_home", match.away_competitor_id => "#{index}_away") }
    end
    
    context 'tournament is round robin' do
      context 'for seasons with even competitors' do
        context 'no results passed' do
          it 'updates other fields of the given matches but does not update ranking or matchday' do
            match = @matches.first
            
            @season.consider_matches({ match.id.to_s => { 'date' => '2015-02-12 17:07:46 UTC', 'home_goals' => '', 'away_goals' => '' } }, 1)
            
            match.reload
            expect(match.home_goals).to be_nil
            expect(match.date.strftime('%d.%m.%Y %H:%M:%S')).to be == '12.02.2015 17:07:46'
            expect(@season.rankings.where(matchday: 1, competitor_id: match.home_competitor_id).first.played).to be_falsey
          end
        end
        
        context 'results passed' do
          context 'results of whole matchday passed' do
            it 'updates ranking for the matchday, also increments current matchday of season and creates ranking for next matchday' do
              @previous_position_1 = @season.rankings.where(matchday: 1, competitor_id: @matches[1].home_competitor_id).first.previous_position
              @previous_position_2 = @season.rankings.where(matchday: 1, competitor_id: @matches[1].away_competitor_id).first.previous_position
              
              expect_season_fixtures 'seasons/round_robin/even_competitors/without_second_leg/whole_first_matchday.txt'
            end
          end  
          
          context 'results of half matchday passed' do
            it 'updates ranking for the matchday' do
              expect_season_fixtures 'seasons/round_robin/even_competitors/without_second_leg/half_first_matchday.txt'
            end
          end
        end
      end
      
      context 'for seasons with odd competitors' do
        let(:competitors_limit) { 3 }
        
        context 'results passed' do
          context 'results of whole matchday passed' do
            it 'updates ranking for the matchday, also increments current matchday of season and creates ranking for next matchday' do
              @previous_position_1 = @season.rankings.where(matchday: 1, competitor_id: @matches[0].home_competitor_id).first.previous_position
              @previous_position_2 = @season.rankings.where(matchday: 1, competitor_id: @matches[0].away_competitor_id).first.previous_position
              @other_competitor_ranking = @season.rankings.where(matchday: 1).
              where('competitor_id NOT IN(?)', [@matches[0].home_competitor_id, @matches[0].away_competitor_id]).first
              @played_on_day2_1 = @season.matches.for_competitor(@matches[0].home_competitor_id).where(matchday: 2).none?
              @played_on_day2_2 = @season.matches.for_competitor(@matches[0].away_competitor_id).where(matchday: 2).none?
              
              expect_season_fixtures 'seasons/round_robin/odd_competitors/without_second_leg/whole_first_matchday.txt'
            end
          end  
        end
      end
    end
    
    context 'tournament is single elimination' do
      let(:system_type) { 1 }
      let(:competitors_limit) { 8 }
      let(:with_second_leg) { true }
      
      it 'ranks by points DESC, matches DESC, goal_differential DESC, goals_scored DESC' do
        expect_season_fixtures 'seasons/single_elimination/even_competitors/with_second_leg/whole_season_for_8.txt'
      end
    end
  end
  
  describe '#generate_matches_for_next_round' do
    let(:with_second_leg) { false }
    let(:third_place_playoff) { false }
    
    before :each do
      @tournament = FactoryGirl.create(
        :tournament, system_type: 1, competitors_limit: 4, with_second_leg: with_second_leg, third_place_playoff: third_place_playoff
      )
      @season = @tournament.current_season
      competitors = []
      user = FactoryGirl.create(:user)
      
      4.times do
        competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
        competitors << competitor
      end
      
      4.times do
        FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitors.shift).accept!
      end
      
      @first_matchday_matches = @season.matches.where(matchday: 1).order('created_at ASC').to_a
      @hash = { 
        @first_matchday_matches[0].home_competitor_id => '0_home', @first_matchday_matches[0].away_competitor_id => '0_away',
        @first_matchday_matches[1].home_competitor_id => '1_home', @first_matchday_matches[1].away_competitor_id => '1_away'
      }
      @matches = [TournamentMatch.new] # will be reloaded if current matchday_fixture has key :reload_fixture 
    end
    
    context 'without second leg' do
      context 'with third place playoff' do
        let(:third_place_playoff) { true }
        
        it 'generates 1 match for each winner of last round and 1 match for each loser of last round' do
          expect_season_fixtures 'seasons/single_elimination/even_competitors/without_second_leg/third_place_playoff/whole_season_for_4.txt'
        end
      end
      
      context 'without third place playoff' do
        it 'generates 1 match for each winner of last round' do
          expect_season_fixtures 'seasons/single_elimination/even_competitors/without_second_leg/whole_season_for_4.txt'
        end
      end
    end

    context 'with second leg' do
      let(:with_second_leg) { true }
      
      it 'generates 2 matches for each winner of last round' do
        @matches << TournamentMatch.new
        expect_season_fixtures 'seasons/single_elimination/even_competitors/with_second_leg/whole_season_for_4.txt'
      end
    end
  end
end