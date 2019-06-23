class CreateWkSurveyReview < ActiveRecord::Migration[4.2]
	def change

		create_table :wk_survey_reviews do |t|
			t.references :user, :class => "User", :null => false, index: true
			t.references :survey_response, :class => "wk_survey_responses", :null => false, index: true
			t.references :survey_question, :class => "wk_survey_questions", :null => false, index: true
			t.text :comment_text
			t.timestamps null: false
		end

		create_table :wk_statuses do |t|
			t.references :status_for, polymorphic: true, index: true
			t.string :status, :null => false, :limit => 5
			t.datetime :status_date, :null => false
			t.timestamps null: false
		end

		rename_table :wk_survey_sel_choices, :wk_survey_answers
		add_column :wk_surveys, :is_review, :boolean, :default => false, :null => false
		add_column :wk_survey_questions, :is_reviewer_only, :boolean, :default => false, :null => false
		add_column :wk_survey_questions, :is_mandatory, :boolean, :default => false, :null => false
		add_column :wk_projects, :is_billable, :boolean, :default => false, :null => false
		remove_column :wk_survey_responses, :status, :string, :limit => 5

		#For TE Admin permission 
		reversible do |dir|
			dir.up do
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (14, 'T&E ADMIN PRIVILEGE', 'A_TE_PRVLG', '', current_timestamp, current_timestamp);
					SQL
			end
				
			dir.down do 
				execute <<-SQL
					DELETE FROM wk_group_permissions WHERE permission_id IN (SELECT ID FROM wk_permissions WHERE short_name IN ('A_TE_PRVLG'))
				SQL
				
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'A_TE_PRVLG';
				SQL
			end
		end

		#Add two columns for Project Profitablity
		add_column :wk_projects, :profit_overhead_percentage, :float
		add_column :wk_invoice_items, :original_amount, :decimal, :precision=>16, :scale=>2
		add_column :wk_invoice_items, :original_currency, :string, :limit => 5
		add_column :wk_payment_items, :original_amount, :decimal, :precision=>16, :scale=>2
		add_column :wk_payment_items, :original_currency, :string, :limit => 5
		
		#Add three columns for Transaction summary
		add_column :wk_gl_transactions, :tyear, :integer, :default => false, :null => false
		add_column :wk_gl_transactions, :tmonth, :integer, :default => false, :null => false
		add_column :wk_gl_transactions, :tweek, :integer, :default => false, :null => false
	end
end