require 'rubygems'
require 'sinatra'
require 'application.rb'

if ENV["RACK_ENV"] == 'production'
	FileUtils.mkdir_p 'log' unless File.exists?('log')
	log = File.new("log/sinatra.log", "a")
	$stdout.reopen(log)
	$stderr.reopen(log)
end
 
run Sinatra::Application
