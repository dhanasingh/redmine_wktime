# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

module WkexpenseHelper	
	include QueriesHelper
	def options_for_currency
	 #method valid_languages - defined in i18n.rb
	 valid_languages.map {|lang| [ll(lang.to_s, 'number.currency.format.unit'), ll(lang.to_s,'number.currency.format.unit')]}.uniq	 
    end
	
	def render_wkexpense_breadcrumb
		links = []
		links << link_to(l(:label_project_all), {:project_id => nil, :issue_id => nil})	
		links << link_to(h(@project), {:project_id => @project, :issue_id => nil}) if @project	
		if @issue
			if @issue.visible?
				links << link_to_issue(@issue, :subject => false)
			else
				links << "##{@issue.id}"
			end
		end
		breadcrumb links
	end
	
	def select_amount(data, criteria, value)
		if value.to_s.empty?
			data.select {|row| row[criteria].blank? }
		else
			data.select {|row| row[criteria].to_s == value.to_s}
		end
	end
	
	def sum_amount(data)
		sum = 0
		data.each do |row|
			sum += row['amount'].to_f
		end
		sum
	end  
	
	def entries_to_csv(entries)
		decimal_separator = l(:general_csv_decimal_separator)   
		export = CSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
			# csv header fields
			headers = [l(:field_spent_on),
					 l(:field_user),
					 l(:field_activity),
					 l(:field_project),
					 l(:field_issue),
					 l(:field_tracker),
					 l(:field_subject),
					 l(:field_amount),
					 l(:field_comments)
					 ]     

			csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(
                                     c.to_s,
                                     l(:general_csv_encoding) )  }
			# csv lines
			entries.each do |entry|
				fields = [format_date(entry.spent_on),
				  entry.user,
				  entry.activity,
				  entry.project,
				  (entry.issue ? entry.issue.id : nil),
				  (entry.issue ? entry.issue.tracker : nil),
				  (entry.issue ? entry.issue.subject : nil),
				  entry.hours.to_s.gsub('.', decimal_separator),
				  entry.comments
				  ]     

				csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(
                                     c.to_s,
                                     l(:general_csv_encoding) )  }
			end
		end
		export
	end
  
	def format_criteria_value(criteria_options, value)
		if value.blank?
			"[#{l(:label_none)}]"
		elsif k = criteria_options[:klass]
			obj = k.find_by_id(value.to_i)
			if obj.is_a?(Issue)
				obj.visible? ? "#{obj.tracker} ##{obj.id}: #{obj.subject}" : "##{obj.id}"
			else
				obj
			end
		else
			format_value(value, criteria_options[:format])
		end
	end  
  
	def report_to_csv(report) 
		decimal_separator = l(:general_csv_decimal_separator)
		export = CSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
			# Column headers
			headers = report.criteria.collect {|criteria| l(report.available_criteria[criteria][:label]) }
			headers += report.periods
			headers << l(:label_total)			 
			csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s,l(:general_csv_encoding) ) }
			# Content			 
			report_criteria_to_csv(csv, report.available_criteria, report.columns, report.criteria, report.periods, report.amount)
			# Total row
			str_total = Redmine::CodesetUtil.from_utf8(l(:label_total), l(:general_csv_encoding))
			row = [ str_total ] + [''] * (report.criteria.size - 1)
			total = 0
			report.periods.each do |period|
				sum = sum_amount(select_amount(report.amount, report.columns, period.to_s))
				total += sum
				row << (sum > 0 ? ("%.2f" % sum).gsub('.',decimal_separator) : '')
			end
			row << ("%.2f" % total).gsub('.',decimal_separator)
			csv << row
		end
		export
	end

	def report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, amount, level=0)  
		decimal_separator = l(:general_csv_decimal_separator)
		amount.collect {|h| h[criteria[level]].to_s}.uniq.each do |value|
			amount_for_value = select_amount(amount, criteria[level], value)
		next if amount_for_value.empty?
			row = [''] * level
			row << Redmine::CodesetUtil.from_utf8(
                        format_criteria_value(available_criteria[criteria[level]], value).to_s,
                        l(:general_csv_encoding) )
			row += [''] * (criteria.length - level - 1)
			total = 0
			periods.each do |period|
				sum = sum_amount(select_amount(amount_for_value, columns, period.to_s))
				total += sum
				row << (sum > 0 ? ("%.2f" % sum).gsub('.',decimal_separator) : '')
			end
			row << ("%.2f" % total).gsub('.',decimal_separator)	 
	  
			csv << row
			if criteria.length > level + 1
				report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, amount_for_value, level + 1)
			end
		end
	end 	
  
	class WKExpenseReport
		 attr_reader :criteria, :columns, :amount, :total_amount, :periods

      def initialize(project, issue, criteria, columns, expense_entry_scope)
        @project = project
        @issue = issue

        @criteria = criteria || []
        @criteria = @criteria.select{|criteria| available_criteria.has_key? criteria}
        @criteria.uniq!
        @criteria = @criteria[0,3]

        @columns = (columns && %w(year month week day).include?(columns)) ? columns : 'month'
        @scope = expense_entry_scope

        run
      end

      def available_criteria
        @available_criteria || load_available_criteria
      end

      private

      def run
        unless @criteria.empty?
          time_columns = %w(tyear tmonth tweek spent_on)
          @amount = []
          @scope.includes(:issue, :activity).
              group(@criteria.collect{|criteria| @available_criteria[criteria][:sql]} + time_columns).
              joins(@criteria.collect{|criteria| @available_criteria[criteria][:joins]}.compact).
              sum(:amount).each do |hash, amount|
            h = {'amount' => amount}
            (@criteria + time_columns).each_with_index do |name, i|
              h[name] = hash[i]
            end
            @amount << h
          end
          
          @amount.each do |row|
            case @columns
            when 'year'
              row['year'] = row['tyear']
            when 'month'
              row['month'] = "#{row['tyear']}-#{row['tmonth']}"
            when 'week'
              row['week'] = "#{row['spent_on'].cwyear}-#{row['tweek']}"
            when 'day'
              row['day'] = "#{row['spent_on']}"
            end
          end
          
          min = @amount.collect {|row| row['spent_on']}.min
          @from = min ? min.to_date : Date.today

          max = @amount.collect {|row| row['spent_on']}.max
          @to = max ? max.to_date : Date.today
          
          @total_amount = @amount.inject(0) {|s,k| s = s + k['amount'].to_f}

          @periods = []
          # Date#at_beginning_of_ not supported in Rails 1.2.x
          date_from = @from.to_time
          # 100 columns max
          while date_from <= @to.to_time && @periods.length < 100
            case @columns
            when 'year'
              @periods << "#{date_from.year}"
              date_from = (date_from + 1.year).at_beginning_of_year
            when 'month'
              @periods << "#{date_from.year}-#{date_from.month}"
              date_from = (date_from + 1.month).at_beginning_of_month
            when 'week'
              @periods << "#{date_from.to_date.cwyear}-#{date_from.to_date.cweek}"
              date_from = (date_from + 7.day).at_beginning_of_week
            when 'day'
              @periods << "#{date_from.to_date}"
              date_from = date_from + 1.day
            end
          end
        end
      end

      def load_available_criteria
        @available_criteria = { 'project' => {:sql => "#{WkExpenseEntry.table_name}.project_id",
                                              :klass => Project,
                                              :label => :label_project},
                                 'status' => {:sql => "#{Issue.table_name}.status_id",
                                              :klass => IssueStatus,
                                              :label => :field_status},
                                 'version' => {:sql => "#{Issue.table_name}.fixed_version_id",
                                              :klass => Version,
                                              :label => :label_version},
                                 'category' => {:sql => "#{Issue.table_name}.category_id",
                                                :klass => IssueCategory,
                                                :label => :field_category},
                                 'user' => {:sql => "#{WkExpenseEntry.table_name}.user_id",
                                             :klass => User,
                                             :label => :label_user},
                                 'tracker' => {:sql => "#{Issue.table_name}.tracker_id",
                                              :klass => Tracker,
                                              :label => :label_tracker},
                                 'activity' => {:sql => "#{WkExpenseEntry.table_name}.activity_id",
                                               :klass => TimeEntryActivity,
                                               :label => :label_activity},
                                 'issue' => {:sql => "#{WkExpenseEntry.table_name}.issue_id",
                                             :klass => Issue,
                                             :label => :label_issue}
                               }       

        @available_criteria
      end
    end
end
