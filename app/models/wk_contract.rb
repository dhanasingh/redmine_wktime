class WkContract < ActiveRecord::Base
  unloadable
  acts_as_attachable :view_permission => :view_files,
                    :edit_permission => :manage_files,
                    :delete_permission => :manage_files
  belongs_to :project
  belongs_to :account, :class_name => 'WkAccount'
  validate :end_date_is_after_start_date
  
   def end_date_is_after_start_date
		if !end_date.blank?
			if end_date < start_date 
				errors.add(:end_date, "cannot be before the start date") 
			end 
		end
	end
  end
