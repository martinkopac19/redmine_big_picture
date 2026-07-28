class SimplifyBpCapacities < ActiveRecord::Migration[7.2]
  def up
    add_column :bp_capacities, :content, :text unless column_exists?(:bp_capacities, :content)
    %i[allocation s_value maintenance bp_velocity effort_coef].each do |c|
      remove_column :bp_capacities, c if column_exists?(:bp_capacities, c)
    end
  end

  def down
    remove_column :bp_capacities, :content if column_exists?(:bp_capacities, :content)
    add_column :bp_capacities, :allocation, :string
    add_column :bp_capacities, :s_value, :string
    add_column :bp_capacities, :maintenance, :string
    add_column :bp_capacities, :bp_velocity, :string
    add_column :bp_capacities, :effort_coef, :string
  end
end
