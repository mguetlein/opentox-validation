
load "validation/validation_application.rb"
load "report/report_application.rb"


[ 'rubygems', 'sinatra', 'sinatra/url_for' ].each do |lib|
  require lib
end

get '/examples/?' do
  
  transform_example
end

private
def transform_example

  file = File.new("EXAMPLES", "r")
  res = ""
  while (line = file.gets) 
    res += line
  end
  file.close
  
  sub = { "validation_service" => url_for("", :full), 
          #"validation_id" => "??",
          #"model_service" => "??",
          #"model_id" => "??",
          #"dataset_service" => "??",
          "dataset_id" => "Hamster Carcenogenicity"}
  
  sub.each do |k,v|
    res.gsub!(/<#{k}>/,v)
  end
  
  res
end
