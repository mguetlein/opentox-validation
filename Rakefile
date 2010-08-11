require 'rubygems'
require 'rake'
require 'tasks/opentox'

REPORT_GEMS = ['rubygems', 'logger', 'fileutils', 'sinatra', 'sinatra/url_for', 'rest_client', 
  'yaml', 'opentox-ruby-api-wrapper', 'fileutils', 'mime/types', 'abbrev', 
  'rexml/document', 'active_record', 'ar-extensions', 'ruby-plot']
VALIDATION_GEMS = [ 'rubygems', 'sinatra', 'sinatra/url_for', 'opentox-ruby-api-wrapper', 'logger', 'active_record', 'ar-extensions' ]



desc "Install required gems"
task :install_gems do
  (REPORT_GEMS + VALIDATION_GEMS).uniq.each do |g|
    begin
      print "> require "+g+" .. "
      require g
      puts "ok"
    rescue LoadError => ex
      puts "NOT FOUND"
      cmd = "sudo env PATH=$PATH gem install "+g
      puts cmd
      IO.popen(cmd){ |f| puts f.gets }
    end
  end
end


desc "Installs gems and inits db migration"
task :init => [:install_gems, :migrate] do
  #do nothing
end


desc "load config"
task :load_config do
  require 'yaml'
  ENV['RACK_ENV'] = 'test' unless ENV['RACK_ENV']
  basedir = File.join(ENV['HOME'], ".opentox")
  config_dir = File.join(basedir, "config")
  config_file = File.join(config_dir, "#{ENV['RACK_ENV']}.yaml")
  if File.exist?(config_file)
    @@config = YAML.load_file(config_file)
    raise "could not load config, config file: "+config_file.to_s unless @@config
  end
  puts "config loaded"
end

# USER VERSION 0 instead
#desc "Clear database"
#task :clear_db => :load_config  do
#  if  @@config[:database][:adapter]=="mysql"
#    clear = nil
#    IO.popen("locate clear_mysql.sh"){ |f| clear=f.gets.chomp("\n") }
#    raise "clear_mysql.sh not found" unless clear
#    cmd = clear+" "+@@config[:database][:username]+" "+@@config[:database][:password]+" "+@@config[:database][:database]
#    IO.popen(cmd){ |f| puts f.gets }
#  else
#    raise "clear not implemented for database-type: "+@@config[:database][:adapter]
#  end
#end

desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x"
task :migrate => :load_config do
  require 'active_record'
  ActiveRecord::Base.establish_connection(  
       :adapter => @@config[:database][:adapter],
       :host => @@config[:database][:host],
       :database => @@config[:database][:database],
       :username => @@config[:database][:username],
       :password => @@config[:database][:password]
       )  
  ActiveRecord::Base.logger = Logger.new($stdout)
  ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : 3 )
end



