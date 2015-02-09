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
    
    create_table :competitors do |t|
      t.string :name
      t.integer :user_id
      t.timestamps
    end
    
    add_index :competitors, :user_id
    add_index :competitors, [:user_id, :name], unique: true

    create_table :tournaments do |t|
      t.string :name
      t.integer :competitors_limit, limit: 3
      t.integer :current_season_id
      t.integer :user_id
      t.timestamps
    end
    
    add_index :tournaments, :user_id
    add_index :tournaments, [:user_id, :name], unique: true

    create_table :tournament_seasons do |t|
      t.integer :tournament_id
      t.string :name
      t.string :state
      t.timestamps
    end
    
    add_index :tournament_seasons, [:tournament_id, :state]

    create_table :season_participations do |t|
      t.integer :season_id
      t.integer :competitor_id
      t.integer :user_id
      t.string :state
      t.timestamps
    end
    
    add_index :season_participations, [:season_id, :competitor_id], unique: true
  end
  
  def down
    Product.where(name: 'Competition').first.destroy
    
    drop_table :exercise_types
    drop_table :competitors
    drop_table :tournaments
    drop_table :tournament_seasons
    drop_table :season_participations
  end
end
