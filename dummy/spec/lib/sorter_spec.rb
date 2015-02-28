require 'spec_helper'

def compare_primitive_rankings(positions_by_competitor, got_rankings)
  positions_by_competitor.each do |competitor_id, position|
    index = got_rankings.find_index { |r| r[:competitor_id] == competitor_id }
    
    expect(index.nil?).to be_falsey, "Index is nil for competitor ##{competitor_id}: #{got_rankings}"
    
    got_position = index + 1
    message = "competitor ##{competitor_id}: got position #{got_position} but expected #{position}"
    
    if position.is_a? Array
      expect(position.include?(got_position)).to be_truthy, message
    else
      expect(got_position).to be == position, message
    end
  end
end

def expect_tied_competitors_to_be_shuffled(rankings, direct_comparisons, competitor_ids, positions)
  tied_competitor_positions = {}
  competitor_ids.each{|id| tied_competitor_positions[id] = [] }
  
  50.times do
    new_rankings = ::VoluntaryCompetition::Sorter.new(rankings.clone, direct_comparisons).sort
    
    tied_competitor_positions.keys.each do |competitor_id|
      tied_competitor_positions[competitor_id] << new_rankings.find_index { |r| r[:competitor_id] == competitor_id } + 1
    end
  end
   
  tied_competitor_positions.keys.sort.each do |competitor_id|
    expect(tied_competitor_positions[competitor_id].uniq.sort).to be == positions
  end
end

describe VoluntaryCompetition::Sorter do
  describe '#sort' do
    it 'shuffles tied competitors' do
      rankings = [
        { competitor_id: 1, points: 1 }, { competitor_id: 2, points: 3 },
        { competitor_id: 3, points: 6 }, { competitor_id: 4, points: 9 },
        { competitor_id: 5, points: 6 }, { competitor_id: 6, points: 7 }
      ]
      direct_comparisons = { 3 => { 5 => 0 }, 5 => { 3 => 0 } }
    
      new_rankings = ::VoluntaryCompetition::Sorter.new(rankings.clone, direct_comparisons).sort
      
      compare_primitive_rankings({ 4 => 1, 6 => 2, 3 => [3, 4], 5 => [3, 4], 2 => 5, 1 => 6 }, new_rankings)
      
      expect_tied_competitors_to_be_shuffled rankings, direct_comparisons, [3, 5], [3, 4]
    end

    it 'sorts by points DESC, goal_differential DESC, goals_scored DESC, direct_comparison and then shuffles' do
      rankings = [
        { competitor_id: 8, points: 0 },
        { competitor_id: 7, points: 1, goal_differential: 3, goals_scored: 3 },
        { competitor_id: 6, points: 1, goal_differential: 3, goals_scored: 3 },
        { competitor_id: 5, points: 1, goal_differential: 3, goals_scored: 3 },
        { competitor_id: 4, points: 2 },
        { competitor_id: 3, points: 3, goal_differential: 2 },
        { competitor_id: 2, points: 3, goal_differential: 3, goals_scored: 2 },
        { competitor_id: 1, points: 3, goal_differential: 3, goals_scored: 3 }
      ]
      direct_comparisons = { 5 => { 6 => 0, 7 => 0 }, 6 => { 5 => 1, 7 => 1 }, 7 => { 5 => 0, 6 => 0 } }
      
      new_rankings = ::VoluntaryCompetition::Sorter.new(rankings.clone, direct_comparisons).sort
      
      compare_primitive_rankings({ 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => [6, 7], 6 => 5, 7 => [6, 7], 8 => 8 }, new_rankings)
    
      tied_competitor_positions = { 5 => [], 7 => []}
      
      50.times do
        new_rankings = ::VoluntaryCompetition::Sorter.new(rankings.clone, direct_comparisons).sort
        
        tied_competitor_positions.keys.each do |competitor_id|
          tied_competitor_positions[competitor_id] << new_rankings.find_index { |r| r[:competitor_id] == competitor_id } + 1
        end
      end
      
      expect(tied_competitor_positions[5].uniq.sort).to be == [6, 7]
      expect(tied_competitor_positions[7].uniq.sort).to be == [6, 7]
    end
  end
  
  describe '#compare_competitors' do
    context 'not_played_competitors' do
      it 'adds competitor pair to list of tied competitors without comparing other attributes' do
        competitors = (1..5).to_a
        rankings = [
          { competitor_id: 1, points: 3 }, { competitor_id: 2, points: 2, not_played_competitors: [3, 4] }, 
          { competitor_id: 3, points: 2, not_played_competitors: [2] }, { competitor_id: 4, points: 2, not_played_competitors: [2] }, 
          { competitor_id: 5, points: 0 }]
        
        direct_comparisons = { 3 => { 4 => 0 }, 4 => { 3 => 0 } }
      
        new_rankings = ::VoluntaryCompetition::Sorter.new(rankings.clone, direct_comparisons).sort  
      
        competitors.each_with_index do |competitor_id, index|
          ranking = new_rankings[index]
          other_competitor_index = competitors.find_index{|id| id == ranking[:competitor_id] }
          
          if index >= 1 && index <= 3
            expect(
              competitors[1..3].include?(ranking[:competitor_id])
            ).to be_truthy, "Expected any of these competitors[1..3] on position ##{(index + 1)} but found competitor ##{other_competitor_index}"
          else
            expect(ranking[:competitor_id]).to be == competitor_id, "Expected competitor ##{index} on position #{(index + 1)} but found competitor ##{other_competitor_index}"
          end
        end
        
        expect_tied_competitors_to_be_shuffled rankings, direct_comparisons, [2, 3, 4], [2, 3, 4]
      end
    end
  end
  
  describe '#compare_points' do
    it 'sorts competitors by points descending' do
      rankings = [
        { competitor_id: 1, points: 1 }, { competitor_id: 2, points: 2 }
      ]
      
      expect(::VoluntaryCompetition::Sorter.new(rankings.clone, {}).sort).to be == [rankings[1], rankings[0]]
    end
  end
  
  describe '#compare_goal_differential' do
    it 'sorts competitors by goal_differential descending' do
      rankings = [
        { competitor_id: 1, goal_differential: 1 }, { competitor_id: 2, goal_differential: 2 }
      ]
      
      expect(::VoluntaryCompetition::Sorter.new(rankings.clone, {}).sort).to be == [rankings[1], rankings[0]]
    end
  end
  
  describe '#compare_goals_scored' do
    it 'sorts competitors by goals_scored descending' do
      rankings = [
        { competitor_id: 1, goals_scored: 1 }, { competitor_id: 2, goals_scored: 2 }
      ]
      
      expect(::VoluntaryCompetition::Sorter.new(rankings.clone, {}).sort).to be == [rankings[1], rankings[0]]
    end
  end
  
  describe '#direct_comparison' do
    it 'sorts competitors by direct comparison descending' do
      rankings = [{ competitor_id: 1 }, { competitor_id: 2 }]
      direct_comparisons = { 1 => { 2 => 0 }, 2 => { 1 => 1 } }
      
      expect(::VoluntaryCompetition::Sorter.new(rankings.clone, direct_comparisons).sort).to be == [rankings[1], rankings[0]]
    end
  end
end