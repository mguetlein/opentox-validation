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

