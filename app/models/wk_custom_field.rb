class WkCustomField < ActiveRecord::Base
  unloadable
  belongs_to :custom_field, :foreign_key => "custom_fields_id", :primary_key => "id"
  validates :custom_fields_id, presence: true
  validates :display_as, presence: true
  validate :validate_wkcustomfields, :validate_projects, :validate_doc_type
  has_one :project, :foreign_key => "id", :primary_key => "projects_id"
  has_one :enumeration, :foreign_key => "id", :primary_key => "enumerations_id"

  def validate_projects
    errors.add :projects_id, :invalid unless projects_id.in?(User.current.projects.ids << nil)
  end
 
  def validate_doc_type
    errors.add :enumerations_id, :invalid unless enumerations_id.in?(Enumeration.where(type: 'DocumentCategory').ids << nil)
  end

  def validate_wkcustomfields
    errors.add :custom_fields_id, :invalid unless custom_fields_id.in?(CustomField.where(field_format: ['wk_lead', 'crm_contact', 'company']).ids)
  end

  def isDocument?
    @custom_field.type.eql? "DocumentCustomField"
  end

  def displayCreation?
    @render_creation
  end
end
