
post '/test_validation/?' do
  validationExamples = ValidationExamples.select(params[:select])
  return "please \"select\" a single validation example:\n"+ValidationExamples.list if validationExamples.size!=1 or validationExamples[0].size!=1
  OpenTox::Task.as_task do
    v = validationExamples[0][0]
    ex = v.new
    ex.upload_files
    ex.check_requirements
    ex.validate
    raise ex.validation_error if ex.validation_error
    ex.report if params[:report]
    raise ex.report_error if ex.report_error
    ex.validation_uri + (params[:report] ? ","+ex.report_uri : "")
  end
end

