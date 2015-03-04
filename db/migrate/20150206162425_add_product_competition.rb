class AddProductCompetition < ActiveRecord::Migration
  def up
    if Product.where(name: 'Competition').first
    else
      Product.create(name: 'Competition', text: 'Dummy') 
    end
    
    create_table :games do |t|
      t.string :name
      t.timestamps
    end
    
    add_index :games, :name, unique: true

    create_table :exercise_types do |t|
      t.string :name
      t.timestamps
    end
    
    add_index :exercise_types, :name, unique: true

    create_table :game_and_exercise_types do |t|
      t.integer :game_id
      t.integer :exercise_type_id
      t.timestamps
    end

    add_index :game_and_exercise_types, [:game_id, :exercise_type_id], unique: true
    add_index :game_and_exercise_types, :exercise_type_id

    create_table :competitors do |t|
      t.string :name
      t.integer :game_and_exercise_type_id
      t.integer :user_id
      t.timestamps
    end
    
    add_index :competitors, [:user_id, :game_and_exercise_type_id, :name], unique: true, name: 'unique_competitor_index'

    create_table :tournaments do |t|
      t.integer :game_and_exercise_type_id
      t.integer :system_type, limit: 2
      t.string :name
      t.integer :competitors_limit, limit: 2
      t.boolean :with_second_leg, default: false
      t.boolean :with_group_stage, default: false
      t.integer :groups_count, limit: 2
      t.boolean :third_place_playoff, default: false
      t.integer :current_season_id
      t.integer :matchdays_per_season, limit: 2
      t.integer :user_id
      t.timestamps
    end
    
    add_index :tournaments, [:user_id, :game_and_exercise_type_id, :name], unique: true, name: 'unique_tournament_index'

    create_table :tournament_seasons do |t|
      t.integer :tournament_id
      t.string :name
      t.integer :matchdays, limit: 2
      t.integer :current_matchday, limit: 2
      t.boolean :w_of_l_won_grand_finals_first_match_against_w_of_w
      t.string :state
      t.timestamps
    end
    
    add_index :tournament_seasons, [:tournament_id, :state]

    create_table :tournament_season_participations do |t|
      t.integer :season_id
      t.integer :competitor_id
      t.integer :user_id
      t.string :state
      t.timestamps
    end

    add_index :tournament_season_participations, [:season_id, :competitor_id], unique: true, name: 'uniq_tournament_season_participation'

    create_table :tournament_season_rankings do |t|
      t.integer :season_id
      t.integer :group_number, limit: 2
      t.integer :matchday, limit: 2
      t.integer :matches, default: 0, limit: 2
      t.boolean :played, default: false
      t.integer :position
      t.integer :previous_position
      t.integer :trend, limit: 2, default: 0
      t.integer :competitor_id
      t.integer :points, default: 0
      t.integer :wins, default: 0
      t.integer :draws, default: 0
      t.integer :losses, default: 0
      t.integer :goal_differential, default: 0
      t.integer :goals_scored, default: 0
      t.integer :goals_allowed, default: 0
      t.timestamps
    end
    
    add_index :tournament_season_rankings, [:season_id, :group_number, :matchday, :position, :competitor_id], unique: true, name: 'uniq_tournament_season_ranking'

    create_table :tournament_matches do |t|
      t.integer :season_id
      t.integer :group_number, limit: 2
      t.integer :round, limit: 2
      t.integer :matchday, limit: 2
      t.boolean :of_winners_bracket
      t.integer :home_competitor_id
      t.integer :away_competitor_id
      t.integer :home_goals
      t.integer :away_goals
      t.integer :winner_competitor_id
      t.integer :loser_competitor_id
      t.boolean :draw
      t.datetime :date
      t.string :state
      t.timestamps
    end
    
    add_index :tournament_matches, [:season_id, :group_number, :of_winners_bracket, :round, :matchday]   
  end
  
  def down
    Product.where(name: 'Competition').first.destroy

    drop_table :games    
    drop_table :exercise_types
    drop_table :game_and_exercise_types  
    drop_table :competitors
    drop_table :tournaments
    drop_table :tournament_seasons
    drop_table :tournament_season_participations
    drop_table :tournament_season_rankings
    drop_table :tournament_season_group_rankings
    drop_table :tournament_matches
  end
end
