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