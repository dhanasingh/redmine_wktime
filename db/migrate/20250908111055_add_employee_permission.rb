class AddEmployeePermission < ActiveRecord::Migration[6.1]
	def change

		#For Employee Admin permission
		reversible do |dir|
			dir.up do
				WkPermission.create([
				{id: 21, name: "ADMIN EMPLOYEE PRIVILEGE", short_name: "A_EMP", modules: "HR", created_at: 'current_timestamp', updated_at: 'current_timestamp'}
				])
			end

			dir.down do
				WkPermission.where(short_name: "A_EMP").destroy_all
			end
		end
	end
end