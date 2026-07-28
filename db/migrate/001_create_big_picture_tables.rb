class CreateBigPictureTables < ActiveRecord::Migration[7.2]
  def change
    create_table :bp_scores do |t|
      t.integer :issue_id, null: false
      t.string  :stakeholder, null: false
      t.integer :score
      t.integer :scored_by_id
      t.timestamps
    end
    add_index :bp_scores, [:issue_id, :stakeholder], unique: true, name: 'index_bp_scores_on_issue_and_stakeholder'

    create_table :bp_phases do |t|
      t.integer :issue_id, null: false
      t.string  :phase, null: false
      t.string  :state, null: false, default: 'NO'
      t.timestamps
    end
    add_index :bp_phases, [:issue_id, :phase], unique: true, name: 'index_bp_phases_on_issue_and_phase'

    create_table :bp_allocations do |t|
      t.integer :issue_id, null: false
      t.integer :user_id, null: false
      t.string  :month, null: false
      t.string  :label
      t.string  :color
      t.timestamps
    end
    add_index :bp_allocations, [:issue_id, :user_id, :month], unique: true, name: 'index_bp_allocations_unique'
  end
end
