class CreateWkClocksettings < ActiveRecord::Migration
    def change
      create_table :wk_clocksettings do |t|
        t.int :check_clock_state, :null => false
        t.string :clock_interval_url, :null => false
        t.string :check_clock_state_interval
      end
    end
  end
  