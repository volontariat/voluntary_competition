require 'spec_helper'

describe TournamentSeasonRanking do
  describe '.create_by_season' do
    it 'creates ranking for all competitors on first matchday' do
      @tournament = FactoryGirl.create(:tournament, competitors_limit: 4)
      season = @tournament.current_season
      competitors = []
      user = FactoryGirl.create(:user)
      
      4.times do
        competitor = FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type, user: user)
        competitors << competitor
        FactoryGirl.create(:tournament_season_participation, season: season, competitor: competitor).accept!
      end
      
      competitors.each do |competitor|
        expect(season.rankings.where('matchday = 1 AND competitor_id = ?', competitor.id).count).to be == 1
      end
    end
  end
  
  describe '.sort' do
    let(:system_type) { 0 }
    let(:competitors_limit) { 3 }
    
    before :each do
      user = FactoryGirl.create(:user)
      tournament = FactoryGirl.create(:tournament, system_type: system_type, competitors_limit: competitors_limit, user: user)
      season = tournament.seasons.first
      competitors = []
      
      8.times do
        competitors << FactoryGirl.create(:competitor, game_and_exercise_type: tournament.game_and_exercise_type, user: user)
      end
      
      [
        { competitor_id: competitors[7].id, points: 0 },
        { competitor_id: competitors[6].id, points: 1, goals_scored: 3, goals_allowed: 0 },
        { competitor_id: competitors[5].id, points: 1, goals_scored: 3, goals_allowed: 0 },
        { competitor_id: competitors[4].id, points: 1, goals_scored: 3, goals_allowed: 0 },
        { competitor_id: competitors[3].id, points: 2 },
        { competitor_id: competitors[2].id, points: 3, goals_scored: 2, goals_allowed: 0 },
        { competitor_id: competitors[1].id, points: 3, goals_scored: 3, goals_allowed: 0 },
        { competitor_id: competitors[0].id, points: 3, goals_scored: 4, goals_allowed: 1 }
      ].each_with_index do |attributes, index|
        ranking = season.rankings.new(matchday: 1, position: index + 1, previous_position: 0)
        attributes.each {|a, v| ranking.send("#{a}=", v) }
        ranking.save!
      end
      
      match = season.matches.new
      
      { home_competitor_id: competitors[5].id, away_competitor_id: competitors[4].id, home_goals: 1, away_goals: 1, draw: true }.each do |a, v| 
        match.send("#{a}=", v)
      end
        
      match.save(validate: false)
      
      TournamentSeasonRanking.sort(season, 1)
      season.reload
      
      rankings = season.rankings.where(matchday: 1).order('position ASC').to_a
      
      competitors.map(&:id).each_with_index do |competitor_id, index|
        ranking = rankings[index]
        other_competitor_index = competitors.map(&:id).find_index{|id| id == ranking.competitor_id }
        
        if index >= 4 && index <= 6
          expect(
            competitors[4..6].map(&:id).include?(ranking.competitor_id)
          ).to be_truthy, "Expected any of these competitors[4..6] on position ##{ranking.position} but found competitor ##{other_competitor_index}"
        else
          expect(ranking.competitor_id).to be == competitor_id, "Expected competitor ##{index} on position #{ranking.position} but found competitor ##{other_competitor_index}"
        end
      end
    end
    
    context 'tournament is round-robin' do
      it 'sorts by points DESC, goal_differential DESC, goals_scored DESC, direct_comparison and then shuffles' do
      end
    end
    
    context 'tournament is single elimination' do
      let(:system_type) { 1 }
      let(:competitors_limit) { 4 }
      
      it 'sorts by points DESC, matches DESC, goal_differential DESC, goals_scored DESC, direct_comparison and then shuffles' do
        # for matches DESC see tournament_season_spec with fixture seasons/single_elimination/even_competitors/with_second_leg/whole_season_for_8.txt
      end
    end
  end
  
  describe '#goal_differential_formatted' do
    it 'formats goal differential like this' do
      ranking = described_class.new
      ranking.goal_differential = 1
      
      expect(ranking.goal_differential_formatted).to be == '+1'
      
      ranking.goal_differential = 0
      
      expect(ranking.goal_differential_formatted).to be == '0'
    end
  end
  
  describe '#calculate_trend' do
    it 'calculates trend by comparing position and previous_position like this' do
      ranking = described_class.new(position: 1, previous_position: 1)
      ranking.calculate_trend
      
      expect(ranking.trend).to be == 0
      
      ranking = described_class.new(position: 1, previous_position: 2)
      ranking.calculate_trend
      
      expect(ranking.trend).to be == 1
      
      ranking = described_class.new(position: 2, previous_position: 1)
      ranking.calculate_trend
      
      expect(ranking.trend).to be == 2
    end
  end
end