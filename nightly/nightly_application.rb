require "nightly/nightly.rb"

get '/build_nightly/?' do
  dry_run = params[:dry_run]!=nil and params[:dry_run]
  Nightly.build_nightly(dry_run)
end

get '/css_style_sheet/?' do
  perform do |rs|
    "@import \""+params[:css_style_sheet]+"\";"
  end
end

get '/nightly/?' do
  content_type "text/html"
  rep = Nightly.get_nightly
  if rep.is_a?(File)
    result = body(rep)
  else
    result = rep
  end
end
