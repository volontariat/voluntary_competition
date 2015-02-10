# This migration comes from voluntary_competition_engine (originally 20150206162425)
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
      t.string :name
      t.integer :competitors_limit, limit: 3
      t.integer :current_season_id
      t.integer :matchdays_per_season, limit: 3
      t.integer :user_id
      t.timestamps
    end
    
    add_index :tournaments, [:user_id, :game_and_exercise_type_id, :name], unique: true, name: 'unique_tournament_index'

    create_table :tournament_seasons do |t|
      t.integer :tournament_id
      t.string :name
      t.integer :matchdays, limit: 3
      t.integer :current_matchday, limit: 3
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
    
    create_table :tournament_matches do |t|
      t.integer :season_id
      t.integer :matchday, limit: 3
      t.integer :home_competitor_id
      t.integer :away_competitor_id
      t.integer :home_goals
      t.integer :away_goals
      t.integer :winner_competitor_id
      t.integer :loser_competitor_id
      t.boolean :draw
      t.datetime :date
      t.string :state
    end
    
    add_index :tournament_matches, :season_id
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
    drop_table :tournament_matches
  end
end
