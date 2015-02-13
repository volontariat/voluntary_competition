require 'spec_helper'

describe VoluntaryCompetition::Concerns::Model::User::Competitive do
  describe '#join_tournament_season_with_competitors' do
    before :each do
      tournament = FactoryGirl.create(:tournament, competitors_limit: 3)
      @season = tournament.current_season
      @user = FactoryGirl.create(:user)
    end
    
    context 'not joined yet' do
      context 'no competitors selected' do
        it 'shows an error' do
          participation = @user.join_tournament_season_with_competitors(@season, [])
          
          expect(participation.errors[:base]).to include(I18n.t('participations.create.please_select_at_least_one_competitor'))
        end
      end
      
      context 'competitors selected' do
        context 'season needs competitors' do
          it 'creates participations for the selected competitors which belong to the user' do
            competitor = FactoryGirl.create(
              :competitor, game_and_exercise_type: @season.tournament.game_and_exercise_type, user: @user
            )
            foreign_competitor = FactoryGirl.create(
              :competitor, game_and_exercise_type: @season.tournament.game_and_exercise_type
            )
            
            participation = @user.join_tournament_season_with_competitors(@season, [competitor.id, foreign_competitor.id])
            
            expect(participation.errors.empty?).to be_truthy
            expect(@season.participations.where(competitor_id: competitor.id).count).to be == 1
            expect(@season.participations.where(competitor_id: foreign_competitor.id).count).to be == 0
          end
        end
        
        context 'season do not need competitors' do
          it 'does not create any participations and shows an error' do
            user = FactoryGirl.create(:user)
            
            3.times do
              competitor = FactoryGirl.create(
                :competitor, game_and_exercise_type: @season.tournament.game_and_exercise_type, user: user
              )  
              FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitor).accept!
            end
            
            competitor = FactoryGirl.create(
              :competitor, game_and_exercise_type: @season.tournament.game_and_exercise_type, user: @user
            )
            
            participation = @user.join_tournament_season_with_competitors(@season, [competitor.id])
            
            expect(participation.errors[:base]).to include(I18n.t('tournament_seasons.general.no_more_competitors_needed'))
            expect(@season.participations.where(competitor_id: competitor.id).count).to be == 0
          end
        end
      end
    end
    
    context 'already joined' do
      context 'deselected competitors' do
        it 'removes participations for deselected competitors' do
          competitors = []
          
          2.times do
            competitors << FactoryGirl.create(
              :competitor, game_and_exercise_type: @season.tournament.game_and_exercise_type, user: @user
            )  
          end
          
          FactoryGirl.create(:tournament_season_participation, season: @season, competitor: competitors.first)
          
          participation = @user.join_tournament_season_with_competitors(@season, [competitors.last.id])
          
          expect(@season.participations.where(competitor_id: competitors.first.id).count).to be == 0
          expect(@season.participations.where(competitor_id: competitors.last.id).count).to be == 1
        end
      end
    end
  end
end