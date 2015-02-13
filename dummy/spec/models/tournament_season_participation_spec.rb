require 'spec_helper'

describe TournamentSeasonParticipation do
  before :each do
    @tournament = FactoryGirl.create(:tournament, competitors_limit: 1)
  end
  
  describe 'validations' do
    describe '#competitors_limit_of_tournament_not_reached' do
      context 'more competitors needed' do
        it 'is valid' do
          participation = FactoryGirl.build(
            :tournament_season_participation, season: @tournament.current_season, competitor: FactoryGirl.build(:competitor)
          )
          
          participation.valid?
          
          expect(participation.errors[:base]).to_not include(
            I18n.t('activerecord.errors.models.tournament_season_participation.attributes.state.tournament_competitors_limit_reached')
          )
        end
      end

      context 'no more competitors needed' do
        it 'is valid' do
          FactoryGirl.create(
            :tournament_season_participation, season: @tournament.current_season, 
            competitor: FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type)
          ).accept!
          participation = FactoryGirl.create(
            :tournament_season_participation, season: @tournament.current_season, 
            competitor: FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type)
          )
          participation.accept
          
          expect(participation.errors[:base]).to include(
            I18n.t('activerecord.errors.models.tournament_season_participation.attributes.state.tournament_competitors_limit_reached')
          )  
        end
      end
    end
  end
  
  describe '#accept' do
    it 'tries to activate the season' do
      expect(@tournament.current_season).to receive(:activate)
      
      FactoryGirl.create(
        :tournament_season_participation, season: @tournament.current_season, 
        competitor: FactoryGirl.create(:competitor, game_and_exercise_type: @tournament.game_and_exercise_type)
      ).accept!
    end
  end
end