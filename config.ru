require 'rubygems'
require 'sinatra'
require 'application.rb'
require 'fileutils'

FileUtils.mkdir_p 'log' unless File.exists?('log')
log = File.new("log/"+FileUtils.pwd.split("/")[-1]+"-#{ENV["RACK_ENV"]}.log", "a")
$stdout.reopen(log)
$stderr.reopen(log)
$stdout.sync = true
$stderr.sync = true

run Sinatra::Application
