module SendPatch::WelcomeControllerPatch
  def self.included(base)
    base.class_eval do
      def index
        if User.current.logged? && Setting.plugin_redmine_wktime['wk_dashboard_as_home'].to_i == 1
          redirect_to controller: 'wkdashboard', action: 'index'
        end
        @news = News.latest User.current
      end
    end
  end
end