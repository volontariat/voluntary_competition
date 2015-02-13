require 'spec_helper'

describe Tournament do
  describe '.create' do
    it 'creates first season' do
      tournament = FactoryGirl.create(:tournament, first_season_name: '2014/2015')
      
      expect(tournament.current_season.name).to be == tournament.first_season_name
    end
  end
end