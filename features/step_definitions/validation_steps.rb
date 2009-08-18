Given /^"(.*)" exists$/ do |uri|
	Net::HTTP.get_response(URI.parse(uri)).code == 200
end

When /^I POST "([^\"]*)" and "([^\"]*)"$/ do |algorithm_uri, dataset_uri|
  post '/crossvalidation', :algorithm_uri => algorithm_uri, :dataset_uri => dataset_uri
  assert_response :success
end

When /^I POST "([^\"]*)" and "([^\"]*)" and "([^\"]*)"$/ do |algorithm_uri, training_set_uri, test_set_uri|
  post '/validation', :algorithm_uri => algorithm_uri, :test_set_uri => test_set_uri, :training_set_uri => training_set_uri
  assert_response :success
	@validation_uri = response.body
end

When /^I POST a "(.*)"$/ do |uri|
	  pending
end

Then /^I should get a valid validation_uri$/ do
	Net::HTTP.get_response(URI.parse(@validation_uri)).code == ( 200 | 202 )
end

Then /^the validation_uri should return "([^\"]*)" or "([^\"]*)"$/ do |arg1, arg2|
end

Then /^I should get a list of validation results$/ do
	  pending
end

