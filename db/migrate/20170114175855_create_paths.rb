class CreatePaths < ActiveRecord::Migration
  def change
    create_table :paths do |t|
      t.string :start_point
      t.string :end_point
      t.string :bounds
      t.integer :occurences
      t.decimal :unsafe_measure

      t.timestamps
    end
  end
end
