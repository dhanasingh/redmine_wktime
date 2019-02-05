class CreateWkPolls < ActiveRecord::Migration[4.2]
    def change

        create_table :wk_polls do |t|
            t.string :name, :null => false
            t.string :types
            t.string :status, :null => false, :limit => 3, :default => 'O'
            t.boolean :in_active, :default => false
            t.timestamps null: false
        end

        create_table :wk_poll_questions do |t|
            t.string :name, :null => false
            t.string :types
            t.references :poll, :class => "wk_polls", :null => false
            t.timestamps null: false

        create_table :wk_poll_choices do |t|
            t.string :name, :null => false
            t.references :poll_question, :class => "wk_poll_questions", :null => false
            t.float :points
            t.timestamps null: false
        end

        create_table :wk_poll_sel_choices do |t|
            t.references :user, :class => "User", :null => false
            t.references :poll_choice, :class => "wk_poll_choices", :null => false
            t.string :ip_address
            t.timestamps null: false
        end

        end

        add_index  :wk_poll_sel_choices, :user_id
        add_index  :wk_poll_sel_choices, :poll_choice_id
        add_index  :wk_poll_choices, :poll_question_id
        add_index  :wk_poll_questions, :poll_id

    end
end