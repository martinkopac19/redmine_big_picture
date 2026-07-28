class UpdateBpAllocations < ActiveRecord::Migration[7.2]
  def up
    change_column_null :bp_allocations, :issue_id, true
    add_column :bp_allocations, :title, :string unless column_exists?(:bp_allocations, :title)
    if index_exists?(:bp_allocations, [:issue_id, :user_id, :month], name: 'index_bp_allocations_unique')
      remove_index :bp_allocations, name: 'index_bp_allocations_unique'
    end
    add_index :bp_allocations, [:user_id, :month] unless index_exists?(:bp_allocations, [:user_id, :month])
  end

  def down
    remove_index :bp_allocations, [:user_id, :month] if index_exists?(:bp_allocations, [:user_id, :month])
    remove_column :bp_allocations, :title if column_exists?(:bp_allocations, :title)
    change_column_null :bp_allocations, :issue_id, false
  end
end
