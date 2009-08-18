Feature: Run validations
  In order to know the accuracy of future predictions
  a model developer
  wants to run validation experiments and to download their results
  
  Scenario Outline: Run the default validation procedure
		Given "<algorithm_uri>" exists
		And "<dataset_uri>" exists
    When I POST "<algorithm_uri>" and "<dataset_uri>"
		Then I should get a valid validation_uri 

		Examples:
			| algorithm_uri                          | dataset_uri                   |
			| http://webservices.in-silico.ch/lazar/ | http://opentox.org/datasets/1 |
  
  Scenario Outline: Run validation with an external testset
		Given "<algorithm_uri>" exists
		And "<training_set_uri>" exists
		And "<test_set_uri>" exists
    When I POST "<algorithm_uri>" and "<training_set_uri>" and "<test_set_uri>" 
		Then I should get a valid validation_uri 

		Examples:
			| algorithm_uri                          | training_set_uri              | test_set_uri          |
			| http://webservices.in-silico.ch/lazar/ | http://opentox.org/datasets/1 | http://opentox.org/datasets/2|

	Scenario Outline: Get all validations for a dataset
		Given "<dataset_uri>" exists
		When I POST a "<dataset_uri>"
		Then I should get a list of validation results

		Examples:
			|dataset_uri|
			| http://opentox.org/datasets/1 |

  Scenario Outline: Get a validation result
    Given "<validation_uri>" exits
		And the validation is finished
		When I GET the "<validation_uri>" 
		Then I should see XML that validates against "<schema_or_dtd_uri>"
		And the "<validation_uri>" should return "200"

		Examples:
				|validation_uri|schema_or_dtd_uri|

	Scenario Outline: Try to get a validation result while validation is still running
    Given "<validation_uri>" exits
		And the validation is not finished
		When I GET the "<validation_uri>" 
		Then the "<validation_uri>" should return "202"

		Examples:
				|validation_uri|

#	Scenario Outline: Run Y-scrambling
#	Scenario Outline: Run n-fold crossvalidation
#	Scenario Outline: Set algorithm parameters and run valdiation
#	Scenario Outline: Get all validations for a model
