class WkPollQuestion < ActiveRecord::Base

    belongs_to :poll , :class_name => 'WkPoll'
    has_many :wk_poll_choices, foreign_key: "poll_question_id", class_name: "WkPollChoice", :dependent => :destroy
  
    accepts_nested_attributes_for :wk_poll_choices
    validates_presence_of :name
  
  end