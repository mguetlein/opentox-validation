
require 'test/test_examples_util.rb'

class Class
  def humanize
    self.to_s.gsub(/.*::/, "").gsub(/([^^A-Z_])([A-Z])/, '\1-\2').gsub(/_/,"-")
  end
end

module ValidationExamples
  
  class IrisCrossvalidation < CrossValidation
    def initialize
      @dataset_file = File.new("data/IRIS_unitrisk.yaml","r")
      @prediction_feature = "http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk"
      @num_folds = 10
    end
  end
  
  class MajorityIrisCrossvalidation < IrisCrossvalidation
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end

  class LazarIrisCrossvalidation < IrisCrossvalidation
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
      super
    end
  end
  
  ########################################################################################################  
  
  class IrisSplit < SplitTestValidation
    def initialize
      @dataset_file = File.new("data/IRIS_unitrisk.yaml","r")
      @prediction_feature = "http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk"
    end
  end
  
  class LazarIrisSplit < IrisSplit
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
      super
    end
  end
  
  class MajorityIrisSplit < IrisSplit
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end
  
  ########################################################################################################
  
  class HamsterSplit < SplitTestValidation
    def initialize
      @dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
      @prediction_feature = "http://localhost/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
    end
  end
  
  class LazarHamsterSplit < HamsterSplit
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
      super
    end
  end
  
  class MajorityHamsterSplit < HamsterSplit
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end
  
  ########################################################################################################

  class HamsterTrainingTest < TrainingTestValidation
    def initialize
      @test_target_dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
      @training_dataset_file = File.new("data/hamster_carcinogenicity.train.yaml","r")
      @test_dataset_file = File.new("data/hamster_carcinogenicity.test.yaml","r")
      @prediction_feature = "http://localhost/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
    end
  end
  
  class MajorityHamsterTrainingTest < HamsterTrainingTest
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end
  
  class LazarHamsterTrainingTest < HamsterTrainingTest
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
      super
    end
  end
  
  ########################################################################################################  

  class HamsterCrossvalidation < CrossValidation
    def initialize
      @dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
      @prediction_feature = "http://localhost/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
      @num_folds = 10
    end
  end
  
  class MajorityHamsterCrossvalidation < HamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end

  class LazarHamsterCrossvalidation < HamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
      super
    end
  end
  
  ########################################################################################################  

  class ISTHamsterCrossvalidation < CrossValidation
    def initialize
      @dataset_uri = "http://webservices.in-silico.ch/dataset/108"
      @prediction_feature = "http://toxcreate.org/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
    end
  end
  
  class MajorityISTHamsterCrossvalidation < ISTHamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end
  
  class LazarISTHamsterCrossvalidation < ISTHamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
      super
    end
  end
  
  class ISTLazarISTHamsterCrossvalidation < ISTHamsterCrossvalidation
    def initialize
      @algorithm_uri = "http://webservices.in-silico.ch/algorithm/lazar"
      @algorithm_params = "feature_generation_uri=http://webservices.in-silico.ch/algorithm/fminer"
      super
    end
  end
  
  ########################################################################################################  

  class ISTIrisCrossvalidation < CrossValidation
    def initialize
      @dataset_uri = "http://ot-dev.in-silico.ch/dataset/39"
      @prediction_feature = "http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk"
    end
  end
  
  class ISTLazarISTIrisCrossvalidation < ISTIrisCrossvalidation
    def initialize
      @algorithm_uri = "http://ot-dev.in-silico.ch/algorithm/lazar"
      @algorithm_params = "feature_generation_uri=http://ot-dev.in-silico.ch/algorithm/fminer"
      super
    end
  end
  
    ########################################################################################################  

  class ISTEpaCrossvalidation < CrossValidation
    def initialize
      @dataset_uri = "http://ot-dev.in-silico.ch/dataset/69"
      @prediction_feature = "http://ot-dev.in-silico.ch/toxcreate/feature#EPA%20FHM"
    end
  end
  
  class ISTLazarISTEpaCrossvalidation < ISTEpaCrossvalidation
    def initialize
      @algorithm_uri = "http://ot-dev.in-silico.ch/algorithm/lazar"
      @algorithm_params = "feature_generation_uri=http://ot-dev.in-silico.ch/algorithm/fminer"
      super
    end
  end
  
  ########################################################################################################
  
  class LR_AmbitCacoModel < ModelValidation
    def initialize
      @model_uri = "http://apps.ideaconsult.net:8080/ambit2/model/33"
      @test_dataset_uri = "http://apps.ideaconsult.net:8080/ambit2/dataset/R545"
      #@prediction_feature=http://apps.ideaconsult.net:8080/ambit2/feature/22200
    end
  end
  
  ########################################################################################################

  class CacoTrainingTest < TrainingTestValidation
    def initialize
      @training_dataset_uri = "http://ambit.uni-plovdiv.bg:8080/ambit2/dataset/R7798"
      @test_dataset_uri = "http://ambit.uni-plovdiv.bg:8080/ambit2/dataset/R8353"
      @prediction_feature = "http://ambit.uni-plovdiv.bg:8080/ambit2/feature/255510"
    end
  end
  
  class LR_AmbitCacoTrainingTest < CacoTrainingTest
    def initialize
      @algorithm_uri = "http://ambit.uni-plovdiv.bg:8080/ambit2/algorithm/LR"
      super
    end
  end
  
  class MLR_NTUA_CacoTrainingTest < CacoTrainingTest
    def initialize
      @algorithm_uri = "http://opentox.ntua.gr:3003/algorithm/mlr"
      super
    end
  end
  
  class MLR_NTUA2_CacoTrainingTest < CacoTrainingTest
    def initialize
      @algorithm_uri = "http://opentox.ntua.gr:3004/algorithm/mlr"
      super
    end
  end
  
  class MajorityCacoTrainingTest < CacoTrainingTest
    def initialize
      @algorithm_uri = File.join(@@config[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end
  
  ########################################################################################################
    
  @@list = {
      "1" => [ LazarHamsterSplit, MajorityHamsterSplit ],
      "1a" => [ LazarHamsterSplit ],
      "1b" => [ MajorityHamsterSplit ],
      
      "2" => [ LazarHamsterTrainingTest, MajorityHamsterTrainingTest ],
      "2a" => [ LazarHamsterTrainingTest ],
      "2b" => [ MajorityHamsterTrainingTest ],
      
      "3" => [ LazarHamsterCrossvalidation, MajorityHamsterCrossvalidation ],
      "3a" => [ LazarHamsterCrossvalidation ],
      "3b" => [ MajorityHamsterCrossvalidation ],
      
      "4" => [ MajorityISTHamsterCrossvalidation, LazarISTHamsterCrossvalidation, ISTLazarISTHamsterCrossvalidation ],
      "4a" => [ MajorityISTHamsterCrossvalidation ],
      "4b" => [ LazarISTHamsterCrossvalidation ],
      "4c" => [ ISTLazarISTHamsterCrossvalidation ],
      
      "5a" => [ LR_AmbitCacoModel ],
      
      "6" => [ LR_AmbitCacoTrainingTest, MLR_NTUA_CacoTrainingTest, MLR_NTUA2_CacoTrainingTest, MajorityCacoTrainingTest ],
      "6a" => [ LR_AmbitCacoTrainingTest ],
      "6b" => [ MLR_NTUA_CacoTrainingTest ],
      "6c" => [ MLR_NTUA2_CacoTrainingTest ],
      "6d" => [ MajorityCacoTrainingTest ],
      
      "7a" =>  [ LazarIrisSplit ],
      "7b" =>  [ MajorityIrisSplit ],
      
      "8b" => [ MajorityIrisCrossvalidation ],
      
      "9a" => [ ISTLazarISTIrisCrossvalidation ],
      
      "10a" => [ ISTLazarISTEpaCrossvalidation ],
    }
  
  def self.list
    @@list.sort.collect{|k,v| k+":\t"+v.collect{|vv| vv.humanize}.join("\n\t")+"\n"}.to_s #.join("\n")
  end
  
  def self.select(csv_keys)
    res = []
    if csv_keys!=nil and csv_keys.size>0
      csv_keys.split(",").each do |k|
        raise "no key "+k.to_s unless @@list.has_key?(k)
        res << @@list[k]
      end
    end
    return res
  end
  
end

#puts ValidationExamples.list
#puts ValidationExamples.select("1,2a").inspect