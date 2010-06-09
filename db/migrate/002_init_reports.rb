
class InitReports < ActiveRecord::Migration
  def self.up

    create_table :report_datum do |t|
      
      [:report_uri,
       :report_type
       ].each do |p|
        t.column p, :string, :limit => 255
      end
      
      [:created_at ].each do |p|
        t.column p, :datetime 
      end
      
      [:validation_uris, :crossvalidation_uris, :model_uris, :algorithm_uris].each do |p|
        t.column(p, :text, :limit => 16320)
      end
    end
  end

  def self.down
    drop_table :report_datum if table_exists? :report_datum
    if @@config[:reports] and @@config[:reports][:report_dir]
      ["validation", "crossvalidation", "algorithm_comparison"].each do |t|
        dir = File.join(@@config[:reports][:report_dir],t)
        if File.exist?(dir)
          puts "deleting dir "+dir.to_s
          FileUtils.rm_rf(dir)
        end
      end
    end
  end
end

