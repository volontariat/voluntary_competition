class AddProductCompetition < ActiveRecord::Migration
  def up
    if Product.where(name: 'Competition').first
    else
      Product.create(name: 'Competition', text: 'Dummy') 
    end
    
    create_table :competitors do |t|
      t.string :name
      t.integer :user_id
      t.timestamps
    end
    
    add_index :competitors, :user_id
    add_index :competitors, [:user_id, :name], unique: true
  end
  
  def down
    Product.where(name: 'Competition').first.destroy
    
    drop_table :competitors
  end
end
