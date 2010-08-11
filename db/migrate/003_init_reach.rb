
require "reach_reports/reach_properties.rb"

class InitReach < ActiveRecord::Migration
  def self.up
    
    create_table :qmrf_reports do |t|
      [:model_uri
        ].each{ |p| t.column(p,:string,:limit => 255) }
      [:created_at 
        ].each{ |p| t.column(p,:datetime) } 
        
      ReachReports::QmrfProperties.properties.each{ |p| t.column(p,:text, :limit => 16320) }
    end
    
    create_table :qprf_reports do |t|
      [:compound_uri,:dataset_uri,:model_uri,:algorithm_uri
       ].each{ |p| t.column(p,:string,:limit => 255) }
      [:created_at 
        ].each{ |p| t.column(p,:datetime) }
    end
    
  end

  def self.down
    [:qmrf_reports, :qprf_reports].each do |t|
      drop_table t if table_exists? t
    end
  end
end

