class WkTeLock < ActiveRecord::Base
  unloadable
   include Redmine::SafeAttributes
   belongs_to :creator, :class_name => 'User', :foreign_key => 'locked_by'
   belongs_to :updater, :class_name => 'User', :foreign_key => 'updated_by'
  safe_attributes 'lock_date', 'locked_by', 'updated_by'
  # attr_protected :locked_by, :updated_by

  validates_presence_of :lock_date
  
   def initialize(attributes=nil, *args)
    super
  end
  
   def lock_date=(date)
		super
		if lock_date.is_a?(Time)
		  self.lock_date = lock_date.to_date
		end
	end
	def created_on=(date)
		super
		if lock_date.is_a?(Time)
		  self.created_on = created_on.to_date
		end
	end
end
