class WkdashboardController < WkbaseController
# TODO - Make compactible with redmine 4.0
before_action :require_login

require 'SVG/Graph/Bar'
require 'SVG/Graph/BarHorizontal'
require 'SVG/Graph/Pie'
require 'SVG/Graph/Line'
require 'SVG/Graph/Plot'
require 'yaml'

include WkdashboardHelper 
include WkcrmHelper
include WktimeHelper
include WkpayrollHelper

  def index
	if Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? ||
	   Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 0
	   redirect_to :controller => 'wktime',:action => 'index' , :tab => 'wktime'
	else
	  set_filter_session
	  setMembers
	  retrieve_date_range
    end	
  end
  
  def graph
	retrieve_date_range
	data = nil
	@group_id = session[:wkdashboard][:group_id]
	@project_id = session[:wkdashboard][:project_id]

	if @from.blank? && @to.blank?
		@to = User.current.today.end_of_month
		@from = User.current.today.end_of_month - 12.months + 1.days
	elsif @from.blank? && !@to.blank?
		@from = @to - 12.months + 1.days
	elsif @to.blank? && !@from.blank?
		@to = @from + 12.months - 1.days
	end

     graph_yml_data= YAML.load(ERB.new(File.read("#{Rails.root}/#{params[:gPath]}")).result).first   
     graph_datas = eval(graph_yml_data[1]['code_str'])    
     graph = get_graphs(graph_yml_data[1]['chart_type'], graph_datas['fields'], graph_yml_data[0],label_check(graph_yml_data[1]['x_title']), label_check(graph_yml_data[1]['y_title'])) 
    
     graph_yml_data[1]['names_of_data'].each do |data_name|
        graph.add_data(:data => eval(data_name['data']) , :title => label_check(data_name['title']))
     end
    
     data = graph.burn  
	 
		if data
			headers["Content-Type"] = params[:type]
			send_data(data, :type => "image/svg+xml", :disposition => "inline")
		else
			render_404
		end
  end
  
	
  def get_graphs(graphType, fields, graphTitle, xTitle, yTitle)	
	graph = SVG::Graph.const_get(graphType).new(
      :height => 230,
      :width => 330,
      :fields => fields,
      :stack => :side,
      :scale_integers => true,
      :step_x_labels => 2,
      :show_data_values => false,
      :graph_title => graphTitle,
      :show_graph_title => true,
	  :show_x_title => true,
      :x_title => (graphType == "Pie" ? "" : xTitle),
      :show_y_title => true,
      :y_title_text_direction => :bt,
      :y_title => (graphType == "Pie" ? "" : yTitle),
	  :key => (graphType == "Pie" ? false : true),
	  :key_position => :bottom,
	  :show_data_labels =>  true,
	  :show_actual_values => true,
      :show_percent => false,
	  :datapoint_font_size => 10,
      :title_font_size => 14,
      :x_label_font_size => 8,
      :x_title_font_size => 12,
      :y_label_font_size => 8,
      :y_title_font_size => 12,
      :key_font_size => 8
    )
	graph
  end  
  
  def set_filter_session
	if session[:wkdashboard].nil?
		session[:wkdashboard] = {:period_type => params[:period_type], :period => params[:period],:group_id => params[:group_id], :from => @from, :to => @to}
	else
		session[:wkdashboard][:project_id] = params[:project_id]
		session[:wkdashboard][:group_id] = params[:group_id]
		session[:wkdashboard][:period] = params[:period]
		session[:wkdashboard][:from] = params[:from]
		session[:wkdashboard][:to] = params[:to]
	end
  end  

  def setMembers		
	@groups = Group.sorted.all
  end		
end
