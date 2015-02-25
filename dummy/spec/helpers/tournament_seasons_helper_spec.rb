# -*- encoding : utf-8 -*-
require 'spec_helper'

describe TournamentSeasonsHelper do
  describe '#round_title' do
    describe 'round' do
      context 'is rounds[-1]' do
        it 'returns final' do
          expect(helper.round_title(5, 5)).to be == I18n.t('tournament_seasons.general.rounds.final')
        end
      end
      
      context 'is rounds[-2]' do
        it 'returns semi-final' do
          expect(helper.round_title(4, 5)).to be == I18n.t('tournament_seasons.general.rounds.semi_final')
        end
      end
      
      context 'is rounds[-3]' do
        it 'returns quarter-final' do
          expect(helper.round_title(3, 5)).to be == I18n.t('tournament_seasons.general.rounds.quarter_final')
        end
      end
      
      context 'is rounds[-4]' do
        it 'returns round of 16' do
          expect(helper.round_title(2, 5)).to be == I18n.t('tournament_seasons.general.rounds.round_of_16')
        end
      end
      
      context 'is 1 of 5' do
        it 'returns #{round.ordinalize} Round' do
          expect(helper.round_title(1, 5)).to be == "1st #{t('tournament_seasons.general.round')}"
        end
      end
    end
  end
  
  describe '#round_matches_for_competitors' do
    it 'returns the matches of the round for a list of competitors' do
      assign :matches, {
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
      
      expect(helper.round_matches_for_competitors(2, [3, 4]).map(&:id)).to be == [3, 5]
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
end