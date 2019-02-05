class WkPollChoice < ActiveRecord::Base

  has_many :wk_poll_sel_choices, foreign_key: "poll_choice_id", class_name: "WkPollSelChoice", :dependent => :destroy
  belongs_to :poll_question , :class_name => 'WkPollQuestion'

  validates_presence_of :name

end