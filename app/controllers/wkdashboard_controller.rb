class WkdashboardController < ApplicationController
require 'SVG/Graph/Bar'
require 'SVG/Graph/BarHorizontal'
require 'SVG/Graph/Pie'
require 'SVG/Graph/Line'
require 'SVG/Graph/Plot'

  def index
  end
  
  def graph
    data = nil
    case params[:graph]
    when "clock_in_users_over_time"
      data = graph_clock_in_users_over_time
    end
    if data
      headers["Content-Type"] = "image/svg+xml"
      send_data(data, :type => "image/svg+xml", :disposition => "inline")
    else
      render_404
    end
  end
  
  def graph_clock_in_users_over_time
	@date_to = User.current.today# - 4.days
    @date_from = @date_to.at_beginning_of_day()
	@date_to = @date_to.at_end_of_day()
    @date_from = Date.civil(@date_from.year, @date_from.month, 1)
    clock_in_of_user = WkAttendance.
      where("start_time BETWEEN ? AND ?", @date_to.at_beginning_of_day().utc, @date_to.utc).select("user_id, min(start_time) as clock_in").group(:user_id)
    clock_in_per_time = [0] * 24
    clock_in_of_user.each {|c| clock_in_per_time[c.clock_in.at_end_of_hour.hour] += 1 }
	
    fields = []
    today = User.current.today
    24.times {|m| fields << m}

    graph = SVG::Graph::Bar.new(
      :height => 300,
      :width => 800,
      :fields => fields,
      :stack => :side,
      :scale_integers => true,
      :step_x_labels => 2,
      :show_data_values => false,
      :graph_title => l(:label_clock_in_users_over_time),
      :show_graph_title => true
    )

    graph.add_data(
      :data => clock_in_per_time[0..23],
      :title => l(:label_no_of_users)
    )

    graph.burn
  end
end
