module SendPatch::UserPatch
  def self.included(base)
    base.class_eval do

      include LoadPatch::UserNestedSet
      has_one :wk_user, :dependent => :destroy, :class_name => 'WkUser'
      has_many :shift_schdules, :dependent => :destroy, :class_name => 'WkShiftSchedule'
      belongs_to :supervisor, :class_name => 'User', :foreign_key => 'parent_id'
      has_one :address, through: :wk_user

      safe_attributes 'parent_id', 'lft', 'rgt'
      acts_as_attachable :view_permission => :view_files,
                        :edit_permission => :manage_files,
                        :delete_permission => :manage_files

      def erpmineuser
        self.wk_user ||= WkUser.new(:user => self)
      end

    end
  end
end