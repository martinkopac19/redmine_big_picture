class CreateBpProjectMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :bp_project_metrics do |t|
      t.integer :issue_id, null: false
      t.decimal :total_score, precision: 5, scale: 2
      t.integer :dev_readiness
      t.timestamps
    end
    add_index :bp_project_metrics, :issue_id, unique: true
    add_index :bp_project_metrics, :total_score
  end
end
