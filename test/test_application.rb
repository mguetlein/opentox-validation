
post '/test_validation/?' do
  validationExamples = ValidationExamples.select(params[:select])
  return "please \"select\" a single validation example:\n"+ValidationExamples.list if validationExamples.size!=1 or validationExamples[0].size!=1
  task = OpenTox::Task.create("Test validation",url_for("/test_validation",:full)) do |task| 
    v = validationExamples[0][0]
    ex = v.new
    ex.subjectid = @subjectid
    ex.upload_files
    task.progress(10)
    ex.check_requirements
    ex.validate(OpenTox::SubTask.create(task,10,80))
    #raise ex.validation_error if ex.validation_error
    ex.report(OpenTox::SubTask.create(task,80,99)) unless params[:report]=="false"
    #raise ex.report_error if ex.report_error
    if ex.report_uri
      ex.report_uri
    else
      ex.validation_uri
    end
  end
  return_task(task)
end

