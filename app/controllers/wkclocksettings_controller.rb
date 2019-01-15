class WkclocksettingsController < ApplicationController
	unloadable
	include WktimeHelper
	include WkclocksettingsHelper

	def index
		clockSettings_helper = Object.new.extend(WkclocksettingsHelper)
        @clockSettings = clockSettings_helper.getClockSettings
    end

	def update
		wktime_helper = Object.new.extend(WktimeHelper)
		host_with_subdir = wktime_helper.getHostAndDir(request)
        checkClockState = params[:check_clock_state].blank? ? 0 : params[:check_clock_state].to_i
        clockIntervalUrl = params[:clock_interval_url].blank? ? url_for(:controller => 'wkclocksettings', :action => 'checkClockState', :host => host_with_subdir, :only_path => true) : params[:clock_interval_url]
        checkClockStateInterval = params[:check_clock_state_interval].blank? ? '6' : params[:check_clock_state_interval]
        WkClocksetting.where(id: '1').
            first_or_create(check_clock_state: checkClockState, clock_interval_url: clockIntervalUrl, check_clock_state_interval: checkClockStateInterval).
            update(check_clock_state: checkClockState, clock_interval_url: clockIntervalUrl, check_clock_state_interval: checkClockStateInterval)
		redirect_to :controller => 'wkclocksettings',:action => 'index' , :tab => 'wkclocksettings'			
    end

    def checkClockState
		lastAttnEntries = findLastAttnEntry(true)
		
		if !lastAttnEntries.blank?
			lastAttnEntry = lastAttnEntries[0]
		end
		if lastAttnEntry.nil? || lastAttnEntry == 0
			respond_to do |format|
				format.text  { render :text => "clockOff" }
			end
		else
			if lastAttnEntry.end_time.blank?
				respond_to do |format|
					format.text  { render :text => "clockOn" }
				end
			else
				respond_to do |format|
					format.text  { render :text => "clockOff" }
				end
			end
		end
	end
end
  