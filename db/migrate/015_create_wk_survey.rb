class CreateWkSurvey< ActiveRecord::Migration[4.2]
    def change

        create_table :wk_surveys do |t|
            t.string :name, :null => false
            t.string :survey_type
            t.string :status, :null => false, :limit => 3, :default => 'O'
            t.boolean :in_active, :default => false
            t.timestamps null: false
        end

        create_table :wk_survey_questions do |t|
            t.string :name, :null => false
            t.string :question_type
            t.references :survey, :class => "wk_surveys", :null => false, index: true
            t.timestamps null: false
        end

        create_table :wk_survey_choices do |t|
            t.string :name, :null => false
            t.references :survey_question, :class => "wk_survey_questions", :null => false, index: true
            t.float :points
            t.timestamps null: false
        end

        create_table :wk_sel_surveys do |t|
            t.references :survey, :class => "wk_surveys", :null => false, index: true
            t.references :parent, polymorphic: true, index: true
            t.timestamps null: false
        end

        create_table :wk_survey_sel_choices do |t|
            t.references :user, :class => "User", :null => false, index: true
            t.references :survey_choice, :class => "wk_survey_choices", :null => false, index: true
            t.references :sel_survey, :class => "wk_sel_surveys", :null => false, index: true
            t.string :ip_address
            t.timestamps null: false
        end
    end
end