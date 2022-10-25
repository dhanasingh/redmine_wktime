class CreateWkSurvey< ActiveRecord::Migration[4.2]
  def change
		
    create_table :wk_surveys do |t|
      t.string :name, :null => false
      t.string :status, :null => false, :limit => 5, :default => 'N'
      t.references :group, :class => Group
      t.references :survey_for, polymorphic: true, index: true
	  t.boolean :recur, :default => false
	  t.integer :recur_after
      t.timestamps null: false
    end

    create_table :wk_survey_questions do |t|
      t.string :name, :null => false
      t.string :question_type, :limit => 5, :default => 'RB'
      t.references :survey, :class => "wk_surveys", :null => false, index: true
      t.timestamps null: false
    end

    create_table :wk_survey_choices do |t|
      t.string :name, :null => false
      t.references :survey_question, :class => "wk_survey_questions", :null => false, index: true
      t.float :points
      t.timestamps null: false
    end

    create_table :wk_survey_responses do |t|
      t.references :survey, :class => "wk_surveys", :null => false, index: true
      t.references :user, :class => "User", :null => false, index: true
      t.string :status, :null => false, :limit => 5, :default => 'C'
      t.string :ip_address, :limit => 30
      t.timestamps null: false
    end

    create_table :wk_survey_sel_choices do |t|
      t.references :survey_choice, :class => "wk_survey_choices", :null => true, index: true
      t.text :choice_text						   
      t.references :survey_question, :class => "wk_survey_questions", :null => false, index: true
      t.references :survey_response, :class => "wk_survey_responses", :null => false, index: true
      t.timestamps null: false
    end	
    
    reversible do |dir|
      dir.up do
        change_column_null :wk_po_supplier_invoices, :purchase_order_id, true
        execute <<-SQL
          INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (5, 'EDIT SURVEY', 'E_SUR', 'SU', current_timestamp, current_timestamp);
        SQL
      end
      dir.down do
        execute <<-SQL
          DELETE from wk_permissions where name = 'EDIT SURVEY';
        SQL
      end 
    end
  end
end