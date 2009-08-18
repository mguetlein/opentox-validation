ENV['RACK_ENV'] = 'test'
require 'application'
require 'test/unit'
require 'rack/test'


class CrossvalidationTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

end
