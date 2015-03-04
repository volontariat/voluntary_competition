# -*- encoding : utf-8 -*-
require 'spec_helper'

describe TournamentSeasonsHelper do
  describe '#round_title' do
    context 'tournament is single elimination' do
      before :each do
        assign :is_single_elimination, true
        assign :winner_rounds, 5
      end
    
      context 'is rounds[-1]' do
        it 'returns final' do
          expect(helper.round_title(true, 5)).to be == t('tournament_seasons.general.rounds.final')
        end
      end
      
      context 'is rounds[-2]' do
        it 'returns semi-final' do
          expect(helper.round_title(true, 4)).to be == t('tournament_seasons.general.rounds.semi_final')
        end
      end
      
      context 'is rounds[-3]' do
        it 'returns quarter-final' do
          expect(helper.round_title(true, 3)).to be == t('tournament_seasons.general.rounds.quarter_final')
        end
      end
      
      context 'is rounds[-4]' do
        it 'returns round of 16' do
          expect(helper.round_title(true, 2)).to be == t('tournament_seasons.general.rounds.round_of_16')
        end
      end
      
      context 'is 1 of 5' do
        it 'returns #{round.ordinalize} Round' do
          expect(helper.round_title(true, 1)).to be == "1st #{t('tournament_seasons.general.round')}"
        end
      end
    end
    
    context 'tournament is double elimination' do
      before :each do
        assign :is_double_elimination, true  
      end
      
      context 'winner round title' do
        before :each do
          assign :winner_rounds, 6
        end
      
        context 'is rounds[-1]' do
          it 'returns grand finals' do
            expect(helper.round_title(true, 6)).to be == t('tournament_seasons.general.rounds.grand_finals')
          end
        end
        
        context 'is rounds[-2]' do
          it 'returns winners finals' do
            expect(helper.round_title(true, 5)).to be == t('tournament_seasons.general.rounds.winners_finals')
          end
        end
        
        context 'is rounds[-3]' do
          it 'returns semi-final' do
            expect(helper.round_title(true, 4)).to be == t('tournament_seasons.general.rounds.semi_final')
          end
        end
        
        context 'is rounds[-4]' do
          it 'returns quarter-final' do
            expect(helper.round_title(true, 3)).to be == t('tournament_seasons.general.rounds.quarter_final')
          end
        end
        
        context 'is rounds[-5]' do
          it 'returns round of 16' do
            expect(helper.round_title(true, 2)).to be == t('tournament_seasons.general.rounds.round_of_16')
          end
        end
        
        context 'is 1 of 6' do
          it 'returns #{round.ordinalize} Round' do
            expect(helper.round_title(true, 1)).to be == "1st #{t('tournament_seasons.general.round')}"
          end
        end
      end
      
      context 'loser round title' do
        before :each do
          assign :loser_rounds, 4
        end
      
        context 'is rounds[-1]' do
          it 'returns losers finals' do
            expect(helper.round_title(false, 3)).to be == t('tournament_seasons.general.rounds.losers_finals')
          end
        end
        
        context 'is rounds[-2]' do
          it 'returns losers semi-finals' do
            expect(helper.round_title(false, 2)).to be == t('tournament_seasons.general.rounds.losers_semi_finals')
          end
        end
        
        context 'is 1 of 3' do
          it 'returns Losers Round 1' do
            expect(helper.round_title(false, 1)).to be == "#{t('tournament_seasons.general.losers_round')} 1"
          end
        end
      end
    end
  end
  
  describe '#round_matches_for_competitors' do
    it 'returns the matches of the round for a list of competitors' do
      assign :matches, {
        true => {
          1 => {
            1 => [FactoryGirl.build(:tournament_match, id: 1, home_competitor_id: 1, away_competitor_id: 2)]
          },
          2 => {
            2 => [
              FactoryGirl.build(:tournament_match, id: 2, home_competitor_id: 1, away_competitor_id: 2),
              FactoryGirl.build(:tournament_match, id: 3, home_competitor_id: 3, away_competitor_id: 4)
            ],
            3 => [
              FactoryGirl.build(:tournament_match, id: 4, home_competitor_id: 2, away_competitor_id: 1),
              FactoryGirl.build(:tournament_match, id: 5, home_competitor_id: 4, away_competitor_id: 3)
            ]
          }
        }
      }
      
      expect(helper.round_matches_for_competitors(true, 2, [3, 4]).map(&:id)).to be == [3, 5]
    end
  end
  
  describe '#rowspan_for_round_connector' do
    it 'doubles rowspan of 3 #{round}.times' do
      expect(helper.rowspan_for_round_connector(2)).to be == 12
    end
  end
  
  describe '#match_for_round_after_first_one?' do
    it 'returns true if a match can be rendered in bracket for the given first_round_matches_index and round' do
      expect(helper.match_for_round_after_first_one?(0, 2)).to be_truthy
      expect(helper.match_for_round_after_first_one?(1, 2)).to be_falsey
      expect(helper.match_for_round_after_first_one?(2, 2)).to be_truthy
      expect(helper.match_for_round_after_first_one?(3, 2)).to be_falsey
      expect(helper.match_for_round_after_first_one?(4, 2)).to be_truthy
    end
  end
  
  describe '#first_round_matches_index_for_last_match_of_round' do
    it 'does what the name says' do
      assign :matches, {
        true => {
          1 => { 1 => 4.times.to_a.map{|t| FactoryGirl.build(:tournament_match) } }
        }
      }
      
      expect(helper.first_round_matches_index_for_last_match_of_round(2)).to be == 2
    end
  end
end