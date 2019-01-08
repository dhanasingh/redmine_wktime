class WkproductmodelController < WkinventoryController
  unloadable
  before_action :require_login
  
  def index
  end

end
