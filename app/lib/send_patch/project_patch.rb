module SendPatch::ProjectPatch
  def self.included(base)
    base.class_eval do

      has_many :account_projects, :dependent => :destroy, :class_name => 'WkAccountProject'
      #has_many :parents, through: :account_projects
      has_one :wk_project, :dependent => :destroy, :class_name => 'WkProject'

      def erpmineproject
        self.wk_project ||= WkProject.new(:project => self)
      end

    end
  end
end