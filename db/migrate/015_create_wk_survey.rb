class CreateWkSurvey< ActiveRecord::Migration[4.2]
  def change
	
	change_column_null :wk_po_supplier_invoices, :purchase_order_id, true
	
    create_table :wk_surveys do |t|
      t.string :name, :null => false, :limit => 100
      t.string :status, :null => false, :limit => 5, :default => 'N'
      t.references :group, :class => Group
      t.timestamps null: false
    end

    create_table :wk_survey_questions do |t|
      t.string :name, :null => false, :limit => 100
      t.string :question_type, :limit => 5, :default => 'RB'
      t.references :survey, :class => "wk_surveys", :null => false, index: true
      t.timestamps null: false
    end

    create_table :wk_survey_choices do |t|
      t.string :name, :null => false, :limit => 100
      t.references :survey_question, :class => "wk_survey_questions", :null => false, index: true
      t.float :points
      t.timestamps null: false
    end

    create_table :wk_survey_responses do |t|
      t.references :survey, :class => "wk_surveys", :null => false, index: true
      t.references :survey_for, polymorphic: true, index: true
      t.timestamps null: false
    end

    create_table :wk_survey_sel_choices do |t|
      t.references :user, :class => "User", :null => false, index: true
      t.references :survey_choice, :class => "wk_survey_choices", :null => true, index: true
      t.text :choice_text						   
      t.references :survey_question, :class => "wk_survey_questions", :null => false, index: true
      t.references :survey_response, :class => "wk_survey_responses", :null => false, index: true
      t.string :ip_address, :limit => 30
      t.timestamps null: false
    end
  end
end