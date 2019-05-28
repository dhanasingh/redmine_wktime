class CreateWkSurveyReview < ActiveRecord::Migration[4.2]
	def change

		create_table :wk_survey_ans_reviews do |t|
			t.references :user, :class => "User", :null => false, index: true
			t.references :survey_answer, :class => "wk_survey_sel_choices", :null => false, index: true
			t.text :comment_text
			t.timestamps null: false
		end

		create_table :wk_status do |t|
			t.references :status_for, polymorphic: true, index: true
			t.string :status, :null => false, :limit => 5
			t.date :status_date, :null => false
			t.timestamps null: false
		end

		rename_table :wk_survey_sel_choices, :wk_survey_answers
		add_column :wk_surveys, :is_review, :boolean, :default => false, :null => false
		add_column :wk_survey_questions, :is_reviewer_only, :boolean, :default => false, :null => false
		add_column :wk_survey_questions, :is_mandatory, :boolean, :default => false, :null => false
		add_column :wk_projects, :is_billable, :boolean, :default => false, :null => false
		change_column_null :wk_survey_choices, :name, true
		remove_column :wk_survey_responses, :status, :string, :limit => 5

	end
end