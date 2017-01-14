class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.string :name
      t.string :latitude
      t.string :longitude
      t.integer :occurences

      t.timestamps
    end
  end
end
