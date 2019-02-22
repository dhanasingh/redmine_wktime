module WksurveyHelper
include WktimeHelper

  def getSurveyStatusArr
	{
		"" => '',
		l(:label_new) => 'N',
		l(:label_open) => 'O',
		l(:label_close) => 'C'
	}
  end
	
  def getSurveyActiveStatusArr
	{
		"" => '',
		l(:label_active) => '0' ,
		l(:label_inactive) => '1'
	}
  end	
end
