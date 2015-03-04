module TournamentSeasonsHelper
  def round_title(round, rounds)
    index = rounds - round
    
    [
      t('tournament_seasons.general.rounds.final'), t('tournament_seasons.general.rounds.semi_final'),
      t('tournament_seasons.general.rounds.quarter_final'), t('tournament_seasons.general.rounds.round_of_16')
    ][index] || "#{round.ordinalize} #{t('tournament_seasons.general.round')}"  
  end
  
  def round_matches_for_competitors(of_winners_bracket, round, competitor_ids)
    return nil unless @matches[of_winners_bracket].has_key? round
    
    matches = []
    
    @matches[of_winners_bracket][round].keys.sort.each do |matchday|
      @matches[of_winners_bracket][round][matchday].each do |match|
        matches << match if competitor_ids.include?(match.home_competitor_id) && competitor_ids.include?(match.away_competitor_id)
      end
    end
    
    matches
  end
  
  def rowspan_for_round_connector(round)
    rowspan = 3
    round.times { rowspan *= 2 }
    rowspan
  end
  
  def match_for_round_after_first_one?(first_round_matches_index, round)
    first_round_matches_per_round_match = 1
    
    (round - 1).times do
      first_round_matches_per_round_match *= 2
    end
     
    # round 2: first_round_matches_per_round_match = 2 => 0, 2, 4
    # round 3: first_round_matches_per_round_match = 4 => 1, 5, 9
    # round 4: first_round_matches_per_round_match = 8 => 3, 11, 19
    # ...
    offset = (first_round_matches_per_round_match / 2) - 1
    
    begin
      if offset == first_round_matches_index
        return true
      end
      
      offset += first_round_matches_per_round_match
    end while offset <= first_round_matches_index
  
    return false
  end
  
  def first_round_matches_index_for_last_match_of_round(round)
    first_round_matches_index, index = 0, 0
    
    begin
      first_round_matches_index = index if match_for_round_after_first_one?(index, round)
      index += 1
    end while index < @matches[true][1][1].length
    
    first_round_matches_index
  end
end