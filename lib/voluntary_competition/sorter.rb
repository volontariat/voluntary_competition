module VoluntaryCompetition
  class Sorter
    def initialize(table, direct_comparisons)
      @table = table
      @direct_comparisons = direct_comparisons
      @tied_competitors = []
    end
  
    def sort
      @table.sort! { |a, b| compare_competitors(a, b) }#.reverse!
      
      return @table unless @tied_competitors.any?
  
      # Competitors are still tied. Sort by coin toss (shuffle)
      remaining_tied_competitors = @tied_competitors.clone.shuffle

      # combine the ranks of the subtable into the original table
      @table.map do |competitor|
        if @tied_competitors.find { |tied_competitor| tied_competitor[:competitor_id] == competitor[:competitor_id] }
          remaining_tied_competitors.shift
        else
          competitor
        end
      end
    end
  
    private
  
    def compare_competitors(a, b)
      unless a[:not_played_competitors].nil? || !a[:not_played_competitors].include?(b[:competitor_id])
        add_to_tied_competitors(a, b)
        
        return 0 <=> 0
      end
      
      comparison = compare_points(a, b)
      
      return comparison unless comparison.zero?
  
      comparison = compare_goal_differential(a, b)
      
      return comparison unless comparison.zero?
  
      comparison = compare_goals_scored(a, b)
      
      return comparison unless comparison.zero?
      
      comparison = direct_comparison(a, b)
      
      return comparison unless comparison.zero?
      
      add_to_tied_competitors(a, b)
  
      comparison
    end
  
    def compare_points(a, b)
      b[:points] <=> a[:points]
    end
  
    def compare_goal_differential(a, b)
      b[:goal_differential] <=> a[:goal_differential]
    end
  
    def compare_goals_scored(a, b)
      b[:goals_scored] <=> a[:goals_scored]
    end
    
    def direct_comparison(a, b)
      @direct_comparisons[b[:competitor_id]][a[:competitor_id]] <=> @direct_comparisons[a[:competitor_id]][b[:competitor_id]]
    end
  
    def add_to_tied_competitors(*competitors)
      competitors.each { |competitor| @tied_competitors << competitor }
      @tied_competitors.uniq!
    end
  end
end