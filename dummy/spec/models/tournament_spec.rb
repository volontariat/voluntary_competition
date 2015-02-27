require 'spec_helper'

describe Tournament do
  describe 'validations' do
    describe '#system_type_requirements' do
      describe 'competitors limit' do
        context 'is power of two' do
          it 'shows no error for system type' do
            tournament = FactoryGirl.build(:tournament, system_type: 1, competitors_limit: 4)
            
            tournament.valid?
            
            expect(tournament.errors[:system_type].empty?).to be_truthy
          end
        end
        
        context 'is not power of two' do
          it 'shows an error for system type' do
            tournament = FactoryGirl.build(:tournament, competitors_limit: 5)
            
            tournament.valid?
             
            expect(tournament.errors[:system_type].empty?).to be_truthy 
             
            tournament = FactoryGirl.build(:tournament, system_type: 1, competitors_limit: 5)
            
            tournament.valid?
            
            expect(tournament.errors[:system_type]).to include(
              I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_must_be_power_of_two')
            )
          end
        end
      end
      
      context 'is less than 4' do
        it 'shows an error for system type' do
          tournament = FactoryGirl.build(:tournament, competitors_limit: 3)
          
          tournament.valid?
          
          expect(tournament.errors[:system_type].empty?).to be_truthy
          
          tournament = FactoryGirl.build(:tournament, system_type: 1, competitors_limit: 3)
          
          tournament.valid?
          
          expect(tournament.errors[:system_type]).to include(
            I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_should_be_at_least_4')
          )
        end
      end
    end
  end
  
  describe 'callbacks' do
    describe 'before_validation' do
      describe '#reset_third_place_playoff_if_round_robin' do
        it 'does what the name says' do
          
        end
      end
    end
  end
  
  describe '#is_round_robin?' do
    it 'tells if the tournament is round robin' do
      tournament = FactoryGirl.build(:tournament)
      
      expect(tournament.is_round_robin?).to be_truthy
      
      tournament = FactoryGirl.build(:tournament, system_type: 1)
      
      expect(tournament.is_round_robin?).to be_falsey
    end
  end
  
  describe '#is_single_elimination?' do
    it 'tells if the tournament is single elimination' do
      tournament = FactoryGirl.build(:tournament)
      
      expect(tournament.is_single_elimination?).to be_falsey
      
      tournament = FactoryGirl.build(:tournament, system_type: 1)
      
      expect(tournament.is_single_elimination?).to be_truthy      
    end
  end
  
  describe '.create' do
    it 'creates first season' do
      tournament = FactoryGirl.create(:tournament, first_season_name: '2014/2015')
      
      expect(tournament.current_season.name).to be == tournament.first_season_name
    end
  end
end