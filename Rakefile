require 'rubygems'
require 'rake'

@gems = "sinatra emk-sinatra-url-for builder datamapper json_pure do_sqlite3 opentox-ruby-api-wrapper"

desc "Install required gems"
task :install do
	puts `sudo gem install #{@gems}`
end

desc "Update required gems"
task :update do
	puts `sudo gem update #{@gems}`
end

desc "Run tests"
task :test do
	load 'test.rb'
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
  ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
end



