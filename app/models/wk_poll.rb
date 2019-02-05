class WkPoll < ActiveRecord::Base
    
    has_many :wk_poll_questions, foreign_key: "poll_id", class_name: "WkPollQuestion", :dependent => :destroy

    has_many :wk_poll_choices, through: :wk_poll_questions
    accepts_nested_attributes_for :wk_poll_questions
    accepts_nested_attributes_for :wk_poll_choices
	
    validates_presence_of :name
end