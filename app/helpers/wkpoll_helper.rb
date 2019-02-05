module WkpollHelper
include WktimeHelper

  def getPollStatusArr
	{
		"" => '',
		l(:label_open) => 'O',
		l(:label_close) => 'C'
	}
  end
	
  def getPollActiveStatusArr
	{
		"" => '',
		l(:label_active) => '0' ,
		l(:label_inactive) => '1'
	}
  end	
end
