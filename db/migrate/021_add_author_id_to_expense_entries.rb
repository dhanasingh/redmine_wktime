class AddAuthorIdToExpenseEntries < ActiveRecord::Migration[5.1]
  def up
    add_column :wk_expense_entries, :author_id, :integer, :default => nil, :after => :project_id
    # Copy existing user_id to author_id
    WkExpenseEntry.update_all('author_id = user_id')
  end

  def down
    remove_column :wk_expense_entries, :author_id
  end
end