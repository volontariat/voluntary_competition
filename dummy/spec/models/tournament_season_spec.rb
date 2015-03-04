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
      message = "Expected #{matchday_fixture[:number_of_matches_for_current_matchday]} matches on matchday #{@season.current_matchday} but got #{@matches.length}"
      expect(@matches.length).to be == matchday_fixture[:number_of_matches_for_current_matchday], message
    end
    
    if matchday_fixture.has_key?(:preview_rankings)
      hash = {}
      
      matchday_fixture[:preview_rankings][0].each do |matchday|
        @season.rankings.where(matchday: matchday).order('position ASC').each do |ranking|
          key = @hash[ranking.competitor_id].split('_')
          key = "@first_matchday_matches[#{key[0]}].#{key[1]}_competitor_id"
          hash[key] ||= {} 
          attributes = ranking.attributes
          
          attributes.each do |k, v| 
            if [
              'id', 'season_id', 'competitor_id', 'group_number', 'created_at', 'updated_at',
              'previous_position', 'trend'
            ].include?(k.to_s) 
              attributes.delete(k) 
            end
          end
          
          hash[key][matchday] = attributes  
        end
      end
      
      puts JSON.pretty_generate(JSON[hash.to_json])
    elsif matchday_fixture.has_key? :rankings
      compare_rankings(matchday_fixture[:rankings]) 
    end
  end
end

def compare_rankings(expected_rankings)
  expected_rankings.each do |competitor_id, matchdays|
    matchdays.each do |matchday, ranking_attributes|
      ranking_attributes = { global: ranking_attributes } unless ranking_attributes.has_key?(:group)
      
      ranking_attributes.each do |scope, attributes|
        rankings = @season.rankings.where(matchday: matchday, competitor_id: competitor_id)
        rankings = rankings.where(group_number: attributes[:group_number]) if scope == :group
        ranking = rankings.first
        
        if ranking.nil?
          raise "No ranking for #{@hash[competitor_id]} on matchday #{matchday} (#{[scope, attributes[:group_number]]})"
        end
        
        attributes.each do |attribute, value|
          group_message = scope == :group ? " of group ##{attributes[:group_number]}" : ''
          message = if attribute.to_s == 'position'
            "#{@hash[competitor_id]}.#{attribute} on day #{matchday}#{group_message} got #{ranking.send(attribute).inspect} " +
            "but expected #{value.inspect}: #{primitive_rankings(ranking.group_number, matchday)}"
          else
            "#{@hash[competitor_id]}.#{attribute} on day #{matchday}#{group_message} got #{ranking.send(attribute).inspect} " +
            "but expected #{value.inspect}"
          end
          
          if value.is_a? Array
            expect(value.include?(ranking.send(attribute))).to be_truthy, message
          else
            expect(ranking.send(attribute)).to be == value, message
          end
        end
      end
    end
  end
end

def primitive_rankings(group_number, matchday)
  @season.rankings.where(group_number: group_number, matchday: matchday).order('position ASC').map do |ranking|
    attributes = ranking.attributes
    attributes['competitor_id'] = @hash[ranking.competitor_id]
    [:id, :created_at, :updated_at].each {|attribute| attributes.delete attribute.to_s }
    attributes
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
  
  describe '#matchdays_count_for_elimination_stage' do
    let(:system_type) { 1 }
    let(:with_second_leg) { false }
    let(:competitors_limit) { 4 }
    
    before :each do
      @season = TournamentSeason.new
      @season.tournament = FactoryGirl.build(
        :tournament, system_type: system_type, with_second_leg: with_second_leg, competitors_limit: competitors_limit
      )
    end
    
    context 'tournament is single elimination' do
      context 'with 4 competitors' do
        context 'with second leg' do
          let(:with_second_leg) { true }
          
          it 'returns 3' do
            expect(@season.instance_eval{ matchdays_count_for_elimination_stage }).to be == 3
          end
        end
        
        context 'without second leg' do
          it 'returns 2' do
            expect(@season.instance_eval{ matchdays_count_for_elimination_stage }).to be == 2
          end
        end
      end
      
      context 'with 8 competitors' do
        let(:competitors_limit) { 8 }
        
        context 'without second leg' do
          it 'returns 3' do
            expect(@season.instance_eval{ matchdays_count_for_elimination_stage }).to be == 3
          end
        end
      end
    end
    
    context 'tournament is double elimination' do
      let(:system_type) { 2 }
      
      context 'with 4 competitors' do
        context 'with second leg' do
          let(:with_second_leg) { true }
          
          it 'returns 9' do
            expect(@season.instance_eval{ matchdays_count_for_elimination_stage }).to be == 9
          end
        end
        
        context 'without second leg' do
          it 'returns 5' do
            expect(@season.instance_eval{ matchdays_count_for_elimination_stage }).to be == 5
          end
        end
      end
      
      context 'with 8 competitors' do
        let(:competitors_limit) { 8 }
        
        context 'without second leg' do
          it 'returns 8' do
            expect(@season.instance_eval{ matchdays_count_for_elimination_stage }).to be == 8
          end
        end
      end
      
      context 'with 16 competitors' do
        let(:competitors_limit) { 16 }
        
        context 'without second leg' do
          it 'returns 11' do
            expect(@season.instance_eval{ matchdays_count_for_elimination_stage }).to be == 11
          end
        end
      end
    end
  end
  
  describe '#winner_rounds' do
    let(:system_type) { 1 }
    let(:competitors_limit) { 4 }
    let(:with_group_stage) { false }
    let(:groups_count) { nil }
    let(:with_second_leg) { false }
    
    before :each do
      @season = described_class.new
      @season.tournament = FactoryGirl.build(
        :tournament, 
        system_type: system_type, competitors_limit: competitors_limit, with_group_stage: with_group_stage,
        groups_count: groups_count, with_second_leg: with_second_leg
      )
    end
    
    context 'tournament is elimination' do
      context 'tournament is single elimination' do
        context 'with second leg' do
          let(:with_second_leg) { true }
          
          it 'returns 2' do
            expect(@season.winner_rounds).to be == 2
          end
        end
        
        context 'without second leg' do
          context 'with group stage' do
            let(:competitors_limit) { 6 }
            let(:with_group_stage) { true }
            let(:groups_count) { 2 }
            
            it 'returns 2' do
              expect(@season.winner_rounds).to be == 2
            end
          end
          
          context 'without group stage' do
            it 'returns 2' do
              expect(@season.winner_rounds).to be == 2
            end
          end
        end
      end
      
      context 'tournament is double elimination' do
        let(:system_type) { 2 }
        
        context 'with second leg' do
          let(:with_second_leg) { true }
          
          it 'returns 3' do
            expect(@season.winner_rounds).to be == 3
          end
        end
        
        context 'without second leg' do
          context 'with group stage' do
            let(:competitors_limit) { 6 }
            let(:with_group_stage) { true }
            let(:groups_count) { 2 }
            
            it 'returns 3' do
              expect(@season.winner_rounds).to be == 3
            end
          end
          
          context 'without group stage' do
            it 'returns 3' do
              expect(@season.winner_rounds).to be == 3
            end
          end
        end
      end
    end
  end
  
  describe '#loser_rounds' do
    let(:competitors_limit) { 4 }
    
    before :each do 
      @season = described_class.new
      @season.tournament = FactoryGirl.build(:tournament, system_type: 2, competitors_limit: competitors_limit)
    end
    
    context 'with 4 competitors' do
      it 'returns ((winner_rounds - 2) * 2) + 1' do
        expect(@season.loser_rounds).to be == 3
      end
    end
    
    context 'with 8 competitors' do
      let(:competitors_limit) { 8 }
    
      it 'returns ((winner_rounds - 2) * 2) + 1' do
        expect(@season.loser_rounds).to be == 5
      end
    end
    
    context 'with 16 competitors' do
      let(:competitors_limit) { 16 }
    
      it 'returns ((winner_rounds - 2) * 2) + 1' do
        expect(@season.loser_rounds).to be == 7
      end
    end
  end
  
  describe '#generate_matches' do
    let(:system_type) { 0 }
    let(:competitors_limit) { 4 }
    let(:with_group_stage) { false }
    let(:groups_count) { nil }
    let(:with_second_leg) { false }
    
    before :each do
      user = FactoryGirl.create(:user)
      @tournament = FactoryGirl.create(
        :tournament, 
        system_type: system_type, competitors_limit: competitors_limit, with_group_stage: with_group_stage, 
        groups_count: groups_count, with_second_leg: with_second_leg, user: user
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
        context 'without group stage' do
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
        
        context 'with group stage' do
          let(:competitors_limit) { 6 }
          let(:with_group_stage) { true }
          let(:groups_count) { 2 }
          
          it 'generates all possible matches between the accepted competitors of a group' do
            @accepted_competitors.each do |competitor|
              matches = @season.matches.where('home_competitor_id = :id OR away_competitor_id = :id', id: competitor.id).order('matchday ASC').to_a
              expect([[1, 3], [1, 2], [2, 3]].include?(matches.map(&:matchday))).to be_truthy, "Not expected that [[1, 3], [1, 2], [2, 3]] does not include #{matches.map(&:matchday)}"
              expect([[true, false], [false, true]].include?(matches.map{|m| m.home_competitor_id == competitor.id })).to be_truthy
            end
            
            expect(@season.matches.order('group_number DESC').first.group_number).to be == 2
            
            # 1-2,1-3,2-3
            [1, 2].each {|group_number| expect(@season.matches.where(group_number: group_number).count).to be == 3 }
            expect(@season.matchdays).to be == 5
          end
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
    let(:with_group_stage) { false }
    let(:groups_count) { nil }
    let(:with_second_leg) { false }
    
    before :each do
      @tournament = FactoryGirl.create(
        :tournament, 
        system_type: system_type, competitors_limit: competitors_limit, with_second_leg: with_second_leg, with_group_stage: with_group_stage,
        groups_count: groups_count
      )
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
      
      context 'with second leg' do
        let(:competitors_limit) { 8 }
        let(:with_second_leg) { true }
        
        it 'ranks by points DESC, matches DESC, goal_differential DESC, goals_scored DESC' do
          expect_season_fixtures 'seasons/single_elimination/even_competitors/with_second_leg/whole_season_for_8.txt'
        end
      end
      
      def expect_season_fixtures_by_comparison(fixture_path)
        fixtures = load_ruby_fixture fixture_path
        
        @season.tournament.last_matchday_of_group_stage.times do |matchday|
          matchday += 1
          results = {}
          
          @season.matches.where(matchday: matchday).each do |match|
            results[match.id.to_s] = {
              'home_goals' => fixtures[match.home_competitor_id][:comparisons][match.away_competitor_id],
              'away_goals' => fixtures[match.away_competitor_id][:comparisons][match.home_competitor_id]
            }
          end
          
          @season.consider_matches(results, matchday)
        end
        
        rankings = {}
        
        fixtures.each {|competitor_id, hash| rankings[competitor_id] = hash[:rankings]}
        
        compare_rankings(rankings)
      end
      
      context 'without second leg' do
        context 'with group stage' do
          let(:competitors_limit) { 6 }
          let(:with_group_stage) { true }
          let(:groups_count) { 2 }
          
          it 'creates one ranking for for whole tournament, one ranking for each group and generates matches for first round of elimination stage on last group matchday' do
            @competitors = {
              1 => @season.matches.where(group_number: 1).map{|m| [m.home_competitor_id, m.away_competitor_id] }.flatten.uniq,
              2 => @season.matches.where(group_number: 2).map{|m| [m.home_competitor_id, m.away_competitor_id] }.flatten.uniq
            }
            @hash = {}
            
            @competitors.each do |group_number, competitor_ids|
              competitor_ids.each_with_index {|competitor_id, index| @hash[competitor_id] = "#{group_number}.#{index}" }
            end
            
            expect_season_fixtures_by_comparison 'seasons/single_elimination/even_competitors/without_second_leg/with_group_stage/season_until_last_group_matchday.txt'
         
            expect(@season.current_matchday).to be == 4
            expect(@season.matches.where(matchday: 4).count).to be == 2
          end
        end
      end
    end
  end
  
  describe '#generate_matches_for_next_round' do
    let(:system_type) { 1 }
    let(:with_second_leg) { false }
    let(:third_place_playoff) { false }
    let(:competitors_limit) { 4 }
    
    before :each do
      @tournament = FactoryGirl.create(
        :tournament, 
        system_type: system_type, competitors_limit: competitors_limit, with_second_leg: with_second_leg, 
        third_place_playoff: third_place_playoff
      )
      @season = @tournament.current_season
      competitors = []
      user = FactoryGirl.create(:user)
      
      competitors_limit.times do
        competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
        competitors << competitor
      end
      
      competitors_limit.times do
        FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitors.shift).accept!
      end
      
      @hash = {}
      @first_matchday_matches = @season.matches.where(matchday: 1).order('created_at ASC').to_a
      
      @first_matchday_matches.each_with_index do |match, index|
        @hash[match.home_competitor_id] = "#{index}_home"
        @hash[match.away_competitor_id] = "#{index}_away"
      end

      @matches = [TournamentMatch.new] # will be reloaded if current matchday_fixture has key :reload_fixture 
    end
    
    context 'single elimination' do
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
    
    context 'double elimination' do
      let(:system_type) { 2 }
      
      context 'with 4 competitors' do
        context 'without second leg' do
          context 'winner of winner bracket wins first match against winner of loser bracket' do
            it 'generates 1 winner bracket match for each winner of first round plus 1 loser bracket match for each loser of first round and in the end a match between winner bracket and loser bracket winner' do
              expect_season_fixtures 'seasons/double_elimination/even_competitors/4/without_second_leg/w_w_wins_match1_vs_l_w/whole_season.txt'
            end
          end
          
          context 'winner of loser bracket wins first match against winner of winner bracket' do
            it 'generates 1 winner bracket match for each winner of first round plus 1 loser bracket match for each loser of first round, a match between winner bracket and loser bracket winner and a second leg match for final' do
              expect_season_fixtures 'seasons/double_elimination/even_competitors/4/without_second_leg/l_w_wins_match1_vs_w_w/whole_season.txt'
            end
          end
        end
      end
      
      context 'with 8 competitors' do
        let(:competitors_limit) { 8 }
        
        context 'without second leg' do
          context 'winner of winner bracket wins first match against winner of loser bracket' do
            it 'generates 1 winner bracket match for each winner of first round plus 1 loser bracket match for each loser of first round and in the end a match between winner bracket and loser bracket winner' do
              expect_season_fixtures 'seasons/double_elimination/even_competitors/8/without_second_leg/w_w_wins_match1_vs_l_w/whole_season.txt'
            end
          end
        end
      end
      
      context 'with 16 competitors' do
        let(:competitors_limit) { 16 }
        
        context 'without second leg' do
          context 'winner of winner bracket wins first match against winner of loser bracket' do
            it 'generates 1 winner bracket match for each winner of first round plus 1 loser bracket match for each loser of first round and in the end a match between winner bracket and loser bracket winner' do
              expect_season_fixtures 'seasons/double_elimination/even_competitors/16/without_second_leg/w_w_wins_match1_vs_l_w/whole_season.txt'
            end
          end
        end
      end
    end
  end
end