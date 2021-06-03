class AddSourceColumn < ActiveRecord::Migration[5.2]
  def change
    add_reference :wk_skills, :source, polymorphic: true
    add_column :wk_skills, :interest_level, :integer, index: true

    reversible do |dir|
      dir.up do
        WkSkill.where(source_type: nil).update_all("source_id = user_id, source_type='User'")
      end
      dir.down do
        WkSkill.where(source_type: "Project").destroy_all
      end
    end
  end
end