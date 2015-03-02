shared_examples 'a tournament season bracket' do
  context 'without second leg' do
    context 'without third place playoff' do
      let(:fixture_path) { "seasons/single_elimination/even_competitors/#{competitors_limit}/without_second_leg/whole_season_bracket"}
      
      it 'renders the bracket like this' do
      end
    end
    
    context 'with third place playoff' do
      let(:third_place_playoff) { true }
      let(:fixture_path) { "seasons/single_elimination/even_competitors/#{competitors_limit}/without_second_leg/third_place_playoff/whole_season_bracket" }
      
      it 'renders the bracket like this' do
      end
    end
  end
    
  context 'with second leg' do
    let(:with_second_leg) { true }
    let(:matchdays) { with_second_leg_matchdays }
    
    context 'without third place playoff' do
      let(:fixture_path) { "seasons/single_elimination/even_competitors/#{competitors_limit}/with_second_leg/whole_season_bracket" }
      
      it 'renders the bracket like this' do
      end
    end
    
    context 'with third place playoff' do
      let(:third_place_playoff) { true }
      let(:fixture_path) { "seasons/single_elimination/even_competitors/#{competitors_limit}/with_second_leg/third_place_playoff/whole_season_bracket" }
      
      it 'renders the bracket like this' do
      end
    end
  end
end