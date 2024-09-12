class UpdateWkSurveyResponses < ActiveRecord::Migration[6.1]
  def up
    change_column :wk_survey_responses, :ip_address, :string, limit: 60
  end
end