require 'spec_helper'

def create_season
  tournament = FactoryGirl.create(:tournament, competitors_limit: 3)
  @season = tournament.current_season
  competitors = []
  user = FactoryGirl.create(:user)
  
  3.times do
    competitor = FactoryGirl.create(:competitor, game_and_exercise_type: tournament.game_and_exercise_type, user: user)
    competitors << competitor
    FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
  end
end

describe TournamentMatch do
  describe 'validations' do
    before :each do
      create_season
    end
    
    describe '#result_not_changed' do
      it 'works' do
        match = @season.matches.where(matchday: 1).first
        match.attributes = { home_goals: 1, away_goals: 0 }
        
        match.save
        
        expect(match.errors.empty?).to be_truthy
        
        match.attributes = { home_goals: 2, away_goals: 0 }
        match.save
        
        expect(match.errors[:base]).to include(I18n.t('activerecord.errors.models.tournament_match.attributes.base.result_cannot_be_changed'))
      end
    end  
    
    describe '#results_for_current_matchday' do
      context 'matchday equals current matchday of season' do
        it 'shows no error' do
          match = @season.matches.where(matchday: 1).first
          match.attributes = { home_goals: 1, away_goals: 0 }
          
          match.valid?
          
          expect(match.errors[:base].empty?).to be_truthy
        end
      end
      
      context 'matchday does not equal current matchday of season' do
        it 'shows an error' do
          match = @season.matches.where(matchday: 2).first
          match.attributes = { home_goals: 1, away_goals: 0 }
          
          match.valid?
          
          expect(match.errors[:base]).to include(
            I18n.t(
              'activerecord.errors.models.tournament_match.attributes.base.results_only_for_current_matchday',
              matchday: 1
            )
          )
        end
      end
    end
  end
  
  describe '#points_for_competitor' do
    context 'draw' do
      it 'returns 1' do
        match = described_class.new
        match.draw = true
        
        expect(match.points_for_competitor(nil)).to be == 1
      end
    end
    
    context 'competitor is winner' do
      it 'returns 3' do
        match = described_class.new
        match.winner_competitor_id = 1
        
        expect(match.points_for_competitor(1)).to be == 3
      end
    end
    
    context 'competitor is winner' do
      it 'returns 3' do
        match = described_class.new
        match.winner_competitor_id = 2
        
        expect(match.points_for_competitor(1)).to be == 0
      end
    end
  end
  
  describe '#goals_for_competitor' do
    before :each do
      @match = described_class.new(home_competitor_id: 1, home_goals: 2, away_goals: 1)
    end
    
    context 'home competitor == competitor' do
      it 'returns [home_goals, away_goals]' do
        expect(@match.goals_for_competitor(1)).to be == [@match.home_goals, @match.away_goals]
      end
    end
    
    context 'home competitor != competitor' do
      it 'returns [away_goals, home_goals]' do
        expect(@match.goals_for_competitor(2)).to be == [@match.away_goals, @match.home_goals]
      end
    end
  end
  
  describe '#set_winner_and_loser_or_draw' do
    context 'no result given' do
      it 'do not set winner, loser or draw' do
        match = described_class.new
        
        match.valid?
        
        { winner_competitor_id: nil, loser_competitor_id: nil, draw: nil }.each do |attribute, value|
          expect(match.send(attribute)).to be == value
        end
      end
    end
    
    context 'draw' do
      it 'sets the match result to draw' do
        create_season
        match = @season.matches.where(matchday: 1).first
        match.attributes = { home_goals: 1, away_goals: 1 }
        match.valid?
        
        { winner_competitor_id: nil, loser_competitor_id: nil, draw: true }.each do |attribute, value|
          expect(match.send(attribute)).to be == value
        end
      end
    end
    
    context 'home competitor is winner' do
      it 'sets the match result to win for home competitor' do
        create_season
        match = @season.matches.where(matchday: 1).first
        match.attributes = { home_goals: 1, away_goals: 0 }
      
        match.valid?
        
        { winner_competitor_id: match.home_competitor_id, loser_competitor_id: match.away_competitor_id, draw: false }.each do |attribute, value|
          expect(match.send(attribute)).to be == value
        end
      end
    end
    
    context 'away competitor is winner' do
      it 'sets the match result to win for away competitor' do
        create_season
        match = @season.matches.where(matchday: 1).first
        match.attributes = { home_goals: 0, away_goals: 1 }
      
        match.valid?
        
        { winner_competitor_id: match.away_competitor_id, loser_competitor_id: match.home_competitor_id, draw: false }.each do |attribute, value|
          expect(match.send(attribute)).to be == value
        end
      end
    end
  end
end