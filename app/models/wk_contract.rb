class WkContract < ActiveRecord::Base
  unloadable
  acts_as_attachable :view_permission => :view_files,
                    :edit_permission => :manage_files,
                    :delete_permission => :manage_files
  belongs_to :project
  belongs_to :account, :class_name => 'WkAccount'
end
