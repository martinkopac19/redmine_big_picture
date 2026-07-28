class CreateBpCapacities < ActiveRecord::Migration[7.2]
  def change
    create_table :bp_capacities do |t|
      t.integer :user_id, null: false
      t.string  :allocation
      t.string  :s_value
      t.string  :maintenance
      t.string  :bp_velocity
      t.string  :effort_coef
      t.timestamps
    end
    add_index :bp_capacities, :user_id, unique: true
  end
end
