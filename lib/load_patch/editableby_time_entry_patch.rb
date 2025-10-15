module LoadPatch::EditablebyTimeEntryPatch
	def self.included(base)
		base.class_eval do

			def editable_by?(usr)
				# === ERPmine_patch Redmine 6.1 for supervisor edit =====
				wktime_helper = Object.new.extend(WktimeHelper)
				if ((!user.blank? && wktime_helper.isSupervisorForUser(user.id)) && wktime_helper.canSupervisorEdit)
					true
				else
				# =============================
					visible?(usr) && (
						(usr == user && usr.allowed_to?(:edit_own_time_entries, project)) || usr.allowed_to?(:edit_time_entries, project)
					)
				end
			end

		end
	end
end