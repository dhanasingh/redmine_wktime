class CreateWkSurveyQueGroups < ActiveRecord::Migration[6.1]
  def change
    # Create wk_survey_que_groups table
    create_table :wk_survey_que_groups do |t|
      t.string :name
      t.integer :sort_order
      t.references :survey, index: true  # Adds survey_id column and index only, no foreign key
      t.timestamps
    end
	
    add_column :wk_survey_answers, :points, :float
    add_column :wk_survey_responses, :total_points, :float
    add_column :wk_surveys, :use_points, :boolean
    add_reference :wk_survey_questions, :group, class: "WkSurveyQueGroup"
    add_column :wk_survey_questions, :sort_order, :string
    add_column :wk_survey_questions, :header, :string
    add_column :wk_survey_questions, :footer, :string

    
    reversible do |dir|
      dir.up do
        # Create "Ungrouped" groups for surveys that don’t have any groups
        execute <<-SQL
          INSERT INTO wk_survey_que_groups (name, survey_id, created_at, updated_at)
          SELECT '', s.id, NOW(), NOW()
          FROM wk_surveys s
          WHERE NOT EXISTS (
            SELECT 1 FROM wk_survey_que_groups g WHERE g.survey_id = s.id
          );
        SQL

        # Assign ungrouped group_id to questions without group
        execute <<-SQL
          UPDATE wk_survey_questions q
            SET group_id = (
                SELECT id
                FROM wk_survey_que_groups g
                WHERE q.survey_id = g.survey_id
            );
        SQL
      end
    end
  end
end
