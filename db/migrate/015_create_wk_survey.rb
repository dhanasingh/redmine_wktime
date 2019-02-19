class CreateWkSurvey< ActiveRecord::Migration[4.2]
    def change

        create_table :wk_surveys do |t|
            t.string :name, :null => false
            t.string :types
            t.string :status, :null => false, :limit => 3, :default => 'O'
            t.boolean :in_active, :default => false
            t.timestamps null: false
        end

        create_table :wk_survey_questions do |t|
            t.string :name, :null => false
            t.string :types
            t.references :survey, :class => "wk_surveys", :null => false
            t.timestamps null: false

        create_table :wk_survey_choices do |t|
            t.string :name, :null => false
            t.references :survey_question, :class => "wk_survey_questions", :null => false
            t.float :points
            t.timestamps null: false
        end

        create_table :wk_survey_sel_choices do |t|
            t.references :user, :class => "User", :null => false
            t.references :survey_choice, :class => "wk_survey_choices", :null => false
            t.string :ip_address
            t.timestamps null: false
        end

        end

        add_index  :wk_survey_sel_choices, :user_id
        add_index  :wk_survey_sel_choices, :survey_choice_id
        add_index  :wk_survey_choices, :survey_question_id
        add_index  :wk_survey_questions, :survey_id

    end
end