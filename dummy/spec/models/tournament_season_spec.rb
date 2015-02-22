require 'spec_helper'

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
    let(:competitors_limit) { 4 }
    let(:with_second_leg) { false }
    
    before :each do
      @tournament = FactoryGirl.create(:tournament, competitors_limit: competitors_limit, with_second_leg: with_second_leg)
      @season = @tournament.current_season
      @denied_competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type)
      FactoryGirl.create(:tournament_season_participation, season: @season, competitor: @denied_competitor).deny!
      @accepted_competitors = []
      user = FactoryGirl.create(:user)
      
      competitors_limit.times do
        competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
        @accepted_competitors << competitor
        FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
      end
    end
    
    context 'without second leg' do
      context 'with even number of competitors' do
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
      
      context 'with odd number of competitors' do
        let(:competitors_limit) { 3 }
        
        it 'also works with a uneven number of competitors - bye' do
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
  
  describe '#consider_matches' do
    context 'for seasons with even number of competitors' do
      before :each do
        @tournament = FactoryGirl.create(:tournament, competitors_limit: 4)
        @season = @tournament.current_season
        competitors = []
        user = FactoryGirl.create(:user)
        
        4.times do
          competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
          competitors << competitor
          FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
        end
      end
      
      context 'no results passed' do
        it 'updates other fields of the given matches but does not update ranking or matchday' do
          match = @season.matches.where(matchday: 1).first
          
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
            matches = @season.matches.where(matchday: 1)
            previous_position_1 = @season.rankings.where(matchday: 1, competitor_id: matches[1].home_competitor_id).first.previous_position
            previous_position_2 = @season.rankings.where(matchday: 1, competitor_id: matches[1].away_competitor_id).first.previous_position
            
            @season.consider_matches(
              { 
                matches[0].id.to_s => { 'date' => '2015-02-12 17:07:46 UTC', 'home_goals' => '1', 'away_goals' => '1' },
                matches[1].id.to_s => { 'date' => '2015-02-12 17:07:46 UTC', 'home_goals' => '1', 'away_goals' => '0' }  
              }, 
              1
            )
            @season.reload
            
            expect(@season.current_matchday).to be == 2
            
            @hash = { 
              matches[0].home_competitor_id => '0_home', matches[0].away_competitor_id => '0_away',
              matches[1].home_competitor_id => '1_home', matches[1].away_competitor_id => '1_away'
            }
            
            compare_rankings({
              matches[0].home_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: [2, 3], points: 1, wins: 0, draws: 1, losses: 0, goal_differential: 0,
                  goals_scored: 1, goals_allowed: 1 
                },
                2 => {
                  played: false, matches: 1, position: [2, 3], points: 1, wins: 0, draws: 1, losses: 0, goal_differential: 0,
                  goals_scored: 1, goals_allowed: 1 
                }
              },
              matches[0].away_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: [2, 3], points: 1, wins: 0, draws: 1, losses: 0, goal_differential: 0,
                  goals_scored: 1, goals_allowed: 1
                },
                2 => {
                  played: false, matches: 1, position: [2, 3], points: 1, wins: 0, draws: 1, losses: 0, goal_differential: 0,
                  goals_scored: 1, goals_allowed: 1
                }
              },
              matches[1].home_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: 1, points: 3, wins: 1, draws: 0, losses: 0, goal_differential: 1,
                  goals_scored: 1, goals_allowed: 0 
                },
                2 => {
                  played: false, matches: 1, position: 1, points: 3, wins: 1, draws: 0, losses: 0, goal_differential: 1,
                  goals_scored: 1, goals_allowed: 0,
                  trend: if 1 == previous_position_1; 0; elsif 1 < previous_position_1; 1; else; 2; end
                }
              },
              matches[1].away_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: 4, points: 0, wins: 0, draws: 0, losses: 1, goal_differential: -1,
                  goals_scored: 0, goals_allowed: 1 
                },
                2 => {
                  played: false, matches: 1, position: 4, points: 0, wins: 0, draws: 0, losses: 1, goal_differential: -1,
                  goals_scored: 0, goals_allowed: 1,
                  trend: if 4 == previous_position_2; 0; elsif 4 < previous_position_2; 1; else; 2; end
                }
              }
            })
          end
        end  
        
        context 'results of half matchday passed' do
          it 'updates ranking for the matchday' do
            matches = @season.matches.where(matchday: 1)
            previous_position_1 = @season.rankings.where(matchday: 1, competitor_id: matches[1].home_competitor_id).first.previous_position
            previous_position_2 = @season.rankings.where(matchday: 1, competitor_id: matches[1].away_competitor_id).first.previous_position
            
            @season.consider_matches(
              {
                matches[0].id.to_s => { 'date' => '2015-02-12 17:07:46 UTC', 'home_goals' => '', 'away_goals' => '' },
                matches[1].id.to_s => { 'date' => '2015-02-12 17:07:46 UTC', 'home_goals' => '1', 'away_goals' => '0' }  
              }, 
              1
            )
            @season.reload
            
            expect(@season.current_matchday).to be == 1
            
            @hash = { 
              matches[0].home_competitor_id => '0_home', matches[0].away_competitor_id => '0_away',
              matches[1].home_competitor_id => '1_home', matches[1].away_competitor_id => '1_away'
            }
            
            compare_rankings({
              matches[0].home_competitor_id => { 
                1 => {
                  played: false, matches: 0, position: [2, 3], points: 0, wins: 0, draws: 0, losses: 0, goal_differential: 0,
                  goals_scored: 0, goals_allowed: 0 
                }
              },
              matches[0].away_competitor_id => { 
                1 => {
                  played: false, matches: 0, position: [2, 3], points: 0, wins: 0, draws: 0, losses: 0, goal_differential: 0,
                  goals_scored: 0, goals_allowed: 0
                }
              },
              matches[1].home_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: 1, points: 3, wins: 1, draws: 0, losses: 0, goal_differential: 1,
                  goals_scored: 1, goals_allowed: 0 
                }
              },
              matches[1].away_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: 4, points: 0, wins: 0, draws: 0, losses: 1, goal_differential: -1,
                  goals_scored: 0, goals_allowed: 1 
                }
              }
            })
          end
        end
      end
    end
    
    context 'for seasons with odd number of competitors' do
      before :each do
        @tournament = FactoryGirl.create(:tournament, competitors_limit: 3)
        @season = @tournament.current_season
        competitors = []
        user = FactoryGirl.create(:user)
        
        3.times do
          competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
          competitors << competitor
          FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
        end
      end
      
      context 'results passed' do
        context 'results of whole matchday passed' do
          it 'updates ranking for the matchday, also increments current matchday of season and creates ranking for next matchday' do
            matches = @season.matches.where(matchday: 1)
            previous_position_1 = @season.rankings.where(matchday: 1, competitor_id: matches[0].home_competitor_id).first.previous_position
            previous_position_2 = @season.rankings.where(matchday: 1, competitor_id: matches[0].away_competitor_id).first.previous_position
            other_competitor_ranking = @season.rankings.where(matchday: 1).
            where('competitor_id NOT IN(?)', [matches[0].home_competitor_id, matches[0].away_competitor_id]).first
            played_on_day2_1 = @season.matches.for_competitor(matches[0].home_competitor_id).where(matchday: 2).none?
            played_on_day2_2 = @season.matches.for_competitor(matches[0].away_competitor_id).where(matchday: 2).none?
            
            @season.consider_matches(
              { 
                matches[0].id.to_s => { 'date' => '2015-02-12 17:07:46 UTC', 'home_goals' => '1', 'away_goals' => '0' }, 
              }, 
              1
            )
            @season.reload
            
            expect(@season.current_matchday).to be == 2
            
            @hash = { 
              matches[0].home_competitor_id => '0_home', matches[0].away_competitor_id => '0_away',
              other_competitor_ranking.competitor_id => 'other_competitor'
            }
            
            compare_rankings({
              matches[0].home_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: 1, points: 3, wins: 1, draws: 0, losses: 0, goal_differential: 1,
                  goals_scored: 1, goals_allowed: 0 
                },
                2 => {
                  played: played_on_day2_1, matches: 1, position: 1, points: 3, wins: 1, draws: 0, losses: 0, goal_differential: 1,
                  goals_scored: 1, goals_allowed: 0,
                  trend: if 1 == previous_position_1; 0; elsif 1 < previous_position_1; 1; else; 2; end
                }
              },
              matches[0].away_competitor_id => { 
                1 => {
                  played: true, matches: 1, position: 3, points: 0, wins: 0, draws: 0, losses: 1, goal_differential: -1,
                  goals_scored: 0, goals_allowed: 1 
                },
                2 => {
                  played: played_on_day2_2, matches: 1, position: 3, points: 0, wins: 0, draws: 0, losses: 1, goal_differential: -1,
                  goals_scored: 0, goals_allowed: 1,
                  trend: if 3 == previous_position_2; 0; elsif 3 < previous_position_2; 1; else; 2; end
                }
              },
              other_competitor_ranking.competitor_id => {
                1 => {
                  played: true, matches: 0, position: 2, points: 0, wins: 0, draws: 0, losses: 0, goal_differential: 0,
                  goals_scored: 0, goals_allowed: 0 
                },
                2 => {
                  played: false, matches: 0, position: 2, points: 0, wins: 0, draws: 0, losses: 0, goal_differential: 0,
                  goals_scored: 0, goals_allowed: 0,
                  trend: if 2 == other_competitor_ranking.previous_position; 0; elsif 2 < other_competitor_ranking.previous_position; 1; else; 2; end
                }
              }
            })
          end
        end  
      end
    end
  end
end