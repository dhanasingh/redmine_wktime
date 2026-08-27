# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
module WkgrouppermissionHelper
  include WktimeHelper
 
  def getPermissionModules
    modules = {}
    
    WkPermission.distinct.pluck(:modules).each do |mod|
      key = mod.to_s
      if key.blank?
        modules[""] = l(:label_general)
      else
        # Convert module name to i18n key convention
        convention_key = "label_#{key.downcase.gsub(' ', '_')}".to_sym
        modules[key] = I18n.t(convention_key, default: key)
      end
    end
 
    modules[""] ||= l(:label_general)
    call_hook(:helper_permission_modules, {modules: modules})
    modules
  end
end