# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
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

module WkcrmenumerationHelper
include WktimeHelper

	def enumType
		enumerationType = {
			'' => '',
			'LS' => l(:label_lead_source),
			'SS' => l(:label_txn_sales_stage),
			'OT' => l(:label_opportunity_type),
			'AC' => l(:label_account_category),
			'PT' => l(:label_payment_type),
			'LT' => l(:label_location_type),
			'DP' => l(:field_department),
			'CR' => l(:label_relationship),
			'SK' => l(:label_skill_set),
			'IT' => l(:label_interview_type),
			'EC' => l(:label_emerg_contact_type),
			'MS' => l(:label_marital_status),
			'DS' => l(:label_dept_section),
		}
		enumhash = call_hook :external_enum_type
		unless enumhash.blank?
			mergeHash = enumhash.is_a?(Array) ? enumhash.first : enumhash
			mergeHash = eval(mergeHash) if mergeHash.is_a?(String)
			enumerationType = enumerationType.merge(mergeHash)
		end
		enumerationType
	end

	def options_for_enum_select(enumType, value, needBlank)
		ennumArray = Array.new
		defaultValue = 0
		crmenum = WkCrmEnumeration.where(:enum_type => enumType, :active => true).order(enum_type: :asc, position: :asc, name: :asc)
		if !crmenum.blank?
			crmenum.each do | entry|
				ennumArray <<  [I18n.t("#{entry.name.gsub('.', '/')}", :default => entry.name), entry.id  ]
				defaultValue = entry.id if entry.is_default?# === "true"
			end
		end
		if needBlank
			ennumArray.unshift(["",0])
		end
		options_for_select(ennumArray, value.blank? ? defaultValue : value)
	end

	def getEnumerations(enum_type)
		wkcrmenums = WkCrmEnumeration.where(enum_type: enum_type, active: true)
			.order(enum_type: :asc, position: :asc, name: :asc)
		enums = []
		enums = wkcrmenums.map{ |enum| { value: enum.id, label: enum.name }}
		enums
	end

end
