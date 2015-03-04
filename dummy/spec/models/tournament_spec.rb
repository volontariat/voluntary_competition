require 'spec_helper'

describe Tournament do
  describe 'validations' do
    describe '#system_type_requirements' do
      describe 'competitors limit' do
        context 'is power of two' do
          it 'shows no error for system type' do
            tournament = FactoryGirl.build(:tournament, system_type: 1, competitors_limit: 4)
            
            tournament.valid?
            
            expect(tournament.errors[:competitors_limit].empty?).to be_truthy
          end
        end
        
        context 'is not power of two' do
          context 'without group stage' do
            it 'shows an error for system type' do
              tournament = FactoryGirl.build(:tournament, competitors_limit: 5)
              
              tournament.valid?
               
              expect(tournament.errors[:competitors_limit].empty?).to be_truthy 
               
              tournament = FactoryGirl.build(:tournament, system_type: 1, competitors_limit: 5)
              
              tournament.valid?
              
              expect(tournament.errors[:competitors_limit]).to include(
                I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_must_be_power_of_two')
              )
            end
          end
          
          context 'with group stage' do
            context 'groups_count * 2 is power of two' do
              it 'shows no error for system type' do
                tournament = FactoryGirl.build(
                  :tournament, system_type: 1, competitors_limit: 6, with_group_stage: true, groups_count: 2
                )
            
                tournament.valid?
            
                expect(tournament.errors[:competitors_limit].empty?).to be_truthy
              end 
            end
            
            context 'groups_count * 2 is not power of two' do
              it 'shows an error for system type' do
                tournament = FactoryGirl.build(
                  :tournament, system_type: 1, competitors_limit: 9, with_group_stage: true, groups_count: 3
                )
            
                tournament.valid?
            
                expect(tournament.errors[:competitors_limit]).to include(
                  I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_must_be_power_of_two')
                )
              end 
            end
          end
        end
        
        context 'is less than 4' do
          it 'shows an error for system type' do
            tournament = FactoryGirl.build(:tournament, competitors_limit: 3)
            
            tournament.valid?
            
            expect(tournament.errors[:competitors_limit].empty?).to be_truthy
            
            tournament = FactoryGirl.build(:tournament, system_type: 1, competitors_limit: 3)
            
            tournament.valid?
            
            expect(tournament.errors[:competitors_limit]).to include(
              I18n.t('activerecord.errors.models.tournament.attributes.system_type.competitors_limit_should_be_at_least_4')
            )
          end
        end
      end
      
      describe 'groups_count' do
        it 'should return 0 for the result about the modulo check between competitors_limit' do
          tournament = FactoryGirl.build(:tournament, system_type: 1, with_group_stage: true, competitors_limit: 6, groups_count: 2)
            
          tournament.valid?
          
          expect(tournament.errors[:groups_count].empty?).to be_truthy
          
          tournament = FactoryGirl.build(:tournament, system_type: 1, with_group_stage: true, competitors_limit: 6, groups_count: 4)
          
          tournament.valid?
          
          expect(tournament.errors[:groups_count]).to include(
            I18n.t('activerecord.errors.models.tournament.attributes.system_type.groups_count_invalid')
          )
        end
        
        it 'should return >= 3 for competitors_limit / groups_count' do
          tournament = FactoryGirl.build(:tournament, system_type: 1, with_group_stage: true, competitors_limit: 6, groups_count: 2)
            
          tournament.valid?
          
          expect(tournament.errors[:groups_count].empty?).to be_truthy
          
          tournament = FactoryGirl.build(:tournament, system_type: 1, with_group_stage: true, competitors_limit: 6, groups_count: 3)
          
          tournament.valid?
          
          expect(tournament.errors[:groups_count]).to include(
            I18n.t('activerecord.errors.models.tournament.attributes.system_type.groups_with_at_least_3_competitors')
          )
        end
      end
    end
  end
  
  describe 'callbacks' do
    describe 'before_validation' do
      describe '#reset_elimination_attributes_if_attributes_are_not_compatible_with_system_type' do
        context 'tournament is round-robin' do
          it 'does what the name says' do
            tournament = FactoryGirl.build(:tournament, with_group_stage: true, third_place_playoff: true, groups_count: 1)
            
            tournament.valid?
            
            expect(tournament.with_group_stage).to be_falsey
            expect(tournament.groups_count).to be == nil
            expect(tournament.third_place_playoff).to be_falsey
          end
        end
        
        context 'tournament is double elimination' do
          it 'does what the name says' do
            tournament = FactoryGirl.build(
              :tournament, system_type: 2, with_group_stage: true, third_place_playoff: true, groups_count: 2
            )
            
            tournament.valid?
            
            expect(tournament.with_group_stage).to be_truthy
            expect(tournament.groups_count).to be == 2
            expect(tournament.third_place_playoff).to be_falsey
          end
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
  
  describe '#is_double_elimination?' do
    it 'tells if the tournament is double elimination' do
      tournament = FactoryGirl.build(:tournament)
      
      expect(tournament.is_double_elimination?).to be_falsey
      
      tournament = FactoryGirl.build(:tournament, system_type: 2)
      
      expect(tournament.is_double_elimination?).to be_truthy      
    end
  end
  
  describe '#is_elimination?' do
    it 'tells if the tournament is elimination' do
      tournament = FactoryGirl.build(:tournament)
      
      expect(tournament.is_elimination?).to be_falsey
      
      tournament = FactoryGirl.build(:tournament, system_type: 1)
      
      expect(tournament.is_elimination?).to be_truthy    
      
      tournament = FactoryGirl.build(:tournament, system_type: 2)
      
      expect(tournament.is_elimination?).to be_truthy      
    end
  end
  
  describe '.create' do
    it 'creates first season' do
      tournament = FactoryGirl.create(:tournament, first_season_name: '2014/2015')
      
      expect(tournament.current_season.name).to be == tournament.first_season_name
    end
  end
end