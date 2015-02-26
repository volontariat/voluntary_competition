require 'spec_helper'

def create_season
  tournament = FactoryGirl.create(:tournament, system_type: system_type, with_second_leg: with_second_leg, competitors_limit: competitors_limit)
  @season = tournament.current_season
  competitors = []
  user = FactoryGirl.create(:user)
  
  competitors_limit.times do
    competitor = FactoryGirl.create(:competitor, game_and_exercise_type: tournament.game_and_exercise_type, user: user)
    competitors << competitor
    FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
  end
end

describe TournamentMatch do
  let(:system_type) { 0 }
  let(:with_second_leg) { false }
  let(:competitors_limit) { 3 }
  
  describe 'validations' do
    before :each do
      create_season
    end
    
    describe '#goals_for_both_sides_or_both_blank' do
      it 'avoids passing only goals for one side' do
        match = @season.matches.where(matchday: 1).first
        
        match.valid?
        
        expect(match.errors[:base].empty?).to be_truthy
        
        match.home_goals = 1
        
        match.valid?
        
        expect(match.errors[:base]).to include(I18n.t('activerecord.errors.models.tournament_match.attributes.base.need_goals_for_both_sides'))
        
        match.home_goals = nil
        match.away_goals = 1
        
        match.valid?
        
        expect(match.errors[:base]).to include(I18n.t('activerecord.errors.models.tournament_match.attributes.base.need_goals_for_both_sides'))
        
        match.home_goals = 1
        
        match.valid?
        
        expect(match.errors[:base].empty?).to be_truthy
      end
    end
    
    describe '#result_not_changed' do
      it 'disables changing of results' do
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
    
    describe '#result_of_both_round_matches_is_not_a_draw' do
      let(:with_second_leg) { true }
      
      context 'single elimination tournament with second leg' do
        let(:system_type) { 1 }
        let(:competitors_limit) { 4 }
        
        it 'denies result for second leg match if result of both matches is a draw' do
          matches = @season.matches.where(matchday: 1).order('created_at ASC').to_a
          @season.consider_matches(
            { 
              matches[0].id.to_s => { 'home_goals' => '1', 'away_goals' => '0' },
              matches[1].id.to_s => { 'home_goals' => '2', 'away_goals' => '0' }  
            }, 
            1
          )
          
          match = @season.matches.for_competitors(matches[0].home_competitor_id, matches[0].away_competitor_id).where(matchday: 2).order('created_at ASC').first
          match.home_goals = 1
          match.away_goals = 0
          
          match.valid?
          
          expect(match.errors[:base]).to include(
            I18n.t('activerecord.errors.models.tournament_match.attributes.base.result_of_both_matches_cant_be_a_draw')
          )
          
          match.home_goals = 2
          
          match.valid?
          
          expect(match.errors[:base].empty?).to be_truthy
        end
      end
      
      context 'round-robin tournament with second leg' do
        it 'accepts result for second leg match if result of both matches is a draw' do
          @season.matchdays.times do |matchday|
            matchday += 1
            results = {}
            
            matches = @season.matches.where(matchday: matchday).order('created_at ASC').each do |match|
              results[match.id] = { 'home_goals' => '1', 'away_goals' => '1' }
            end
            
            expect(@season.consider_matches(results, matchday).select{|m| !m.errors.empty? }.none?).to be_truthy
          end
        end
      end
    end
  end
  
  describe '.direct_comparison' do
    it 'returns either the winner, nil for draws or -1 if there are no matches' do
      expect(TournamentMatch.direct_comparison([FactoryGirl.build(:tournament_match)])).to be == -1
      
      expect(
        TournamentMatch.direct_comparison(
          [FactoryGirl.build(:tournament_match, winner_competitor_id: 1)]
        )
      ).to be == 1
      
      expect(
        TournamentMatch.direct_comparison(
          [
            FactoryGirl.build(
              :tournament_match, draw: true, home_competitor_id: 1, away_competitor_id: 2, home_goals: 1, away_goals: 1
            ),
            FactoryGirl.build(
              :tournament_match, draw: true, home_competitor_id: 2, away_competitor_id: 1, home_goals: 2, away_goals: 2
            )
          ]
        )
      ).to be == 1
      
      expect(TournamentMatch.direct_comparison([])).to be == -1
    end
  end
  
  describe '.winner_of_two_matches' do
    it 'returns winner of two matches like this if possible else nil' do
      expect(
        TournamentMatch.winner_of_two_matches(
          [
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 1, away_competitor_id: 2, home_goals: 1, away_goals: 1
            ),
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 2, away_competitor_id: 1, home_goals: 0, away_goals: 1
            )
          ]
        )
      ).to be == 1
      
      expect(
        TournamentMatch.winner_of_two_matches(
          [
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 1, away_competitor_id: 2, home_goals: 1, away_goals: 1
            ),
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 2, away_competitor_id: 1, home_goals: 1, away_goals: 0
            )
          ]
        )
      ).to be == 2
      
      expect(
        TournamentMatch.winner_of_two_matches(
          [
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 1, away_competitor_id: 2, home_goals: 1, away_goals: 1
            ),
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 2, away_competitor_id: 1, home_goals: 2, away_goals: 2
            )
          ]
        )
      ).to be == 1
      
      expect(
        TournamentMatch.winner_of_two_matches(
          [
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 1, away_competitor_id: 2, home_goals: 2, away_goals: 2
            ),
            FactoryGirl.build(
              :tournament_match, home_competitor_id: 2, away_competitor_id: 1, home_goals: 1, away_goals: 1
            )
          ]
        )
      ).to be == 2
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