class CreateWkExpenseEntries < ActiveRecord::Migration
  def change
    create_table :wk_expense_entries do |t|
	  t.column :project_id,  :integer,  :null => false
      t.column :user_id,     :integer,  :null => false
      t.column :issue_id,    :integer
      t.column :amount,      :float,    :null => false
      t.column :comments,    :string,   :limit => 255
      t.column :activity_id, :integer,  :null => false
      t.column :spent_on,    :date,     :null => false
      t.column :tyear,       :integer,  :null => false
      t.column :tmonth,      :integer,  :null => false
      t.column :tweek,       :integer,  :null => false
      t.column :created_on,  :datetime, :null => false
      t.column :updated_on,  :datetime, :null => false
	  t.column :currency,    :string,   :limit => 5, :default => '$'
    end
    add_index :wk_expense_entries, [:project_id], :name => :wk_expense_entries_project_id
    add_index :wk_expense_entries, [:issue_id], :name => :wk_expense_entries_issue_id
	
	create_table :wkexpenses do |t|	
	  t.references :user, :null => false
      t.date :begin_date, :null => false
      t.float :amount, :null => false
      t.string :status, :null => false, :limit => 2, :default => 'n'
      t.date :submitted_on
      t.date :statusupdate_on
	  t.references :submitter, :class => "User", :null => true
	  t.references :statusupdater, :class => "User"
	  t.string :notes
	  t.timestamps null: false
    end
	add_index  :wkexpenses, :user_id
	add_index  :wkexpenses, :begin_date
  end
end
