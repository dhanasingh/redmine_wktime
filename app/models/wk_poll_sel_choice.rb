class WkPollSelChoice < ActiveRecord::Base

  belongs_to :poll_choice , :class_name => 'WkPollChoice'
  belongs_to :user, :class_name => 'User'

  validates_presence_of :user_id, :poll_choice_id
end