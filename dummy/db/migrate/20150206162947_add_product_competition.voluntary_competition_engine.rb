# This migration comes from voluntary_competition_engine (originally 20150206162425)
class AddProductCompetition < ActiveRecord::Migration
  def up
    if Product.where(name: 'Competition').first
    else
      Product.create(name: 'Competition', text: 'Dummy') 
    end
  end
  
  def down
    Product.where(name: 'Competition').first.destroy
  end
end
