module WksurveyHelper
include WktimeHelper

  def getSurveyStatusArr
	{
		"" => '',
		l(:label_new) => 'N',
		l(:label_open) => 'O',
		l(:label_close) => 'C',
		l(:label_archived) => 'A'
	}
  end	
end
