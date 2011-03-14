
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
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end

  class LazarIrisCrossvalidation < IrisCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer")
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
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer")
      super
    end
  end
  
  class MajorityIrisSplit < IrisSplit
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end
  
  ########################################################################################################  
  
  class EPAFHMSplit < SplitTestValidation
    def initialize
      @dataset_file = File.new("data/EPAFHM.csv","r")
      #@prediction_feature = "http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk"
      @split_ratio = 0.95
    end
  end
    
  class LazarEPAFHMSplit < EPAFHMSplit
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  class MajorityEPAFHMSplit < EPAFHMSplit
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end
  
    ########################################################################################################
  
    class EPAFHMCrossvalidation < CrossValidation
    def initialize
      @dataset_file = File.new("data/EPAFHM.csv","r")
      #@prediction_feature = "http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk"
      @num_folds = 10
    end
  end
  
  class MajorityEPAFHMCrossvalidation < EPAFHMCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end

  class LazarEPAFHMCrossvalidation < EPAFHMCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  ########################################################################################################
  
  class HamsterSplit < SplitTestValidation
    def initialize
      #@dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
      @dataset_file = File.new("data/hamster_carcinogenicity.csv","r")
      
      #@prediction_feature = "http://local-ot/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
      #@prediction_feature = "http://local-ot/dataset/1/feature/hamster_carcinogenicity"
    end
  end
  
  class LazarHamsterSplit < HamsterSplit
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  class MajorityHamsterSplit < HamsterSplit
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end
  
  ########################################################################################################
  
  class HamsterBootstrapping < BootstrappingValidation
    def initialize
      #@dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
      @dataset_file = File.new("data/hamster_carcinogenicity.csv","r")
      
      #@prediction_feature = "http://local-ot/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
      #@prediction_feature = "http://local-ot/dataset/1/feature/hamster_carcinogenicity"
    end
  end
  
  class LazarHamsterBootstrapping < HamsterBootstrapping
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  class MajorityHamsterBootstrapping < HamsterBootstrapping
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end  
  
  ########################################################################################################

  class HamsterTrainingTest < TrainingTestValidation
    def initialize
#      @test_target_dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
#      @training_dataset_file = File.new("data/hamster_carcinogenicity.train.yaml","r")
#      @test_dataset_file = File.new("data/hamster_carcinogenicity.test.yaml","r")
      
      @test_target_dataset_file = File.new("data/hamster_carcinogenicity.csv","r")
      @training_dataset_file = File.new("data/hamster_carcinogenicity.train.csv","r")
      @test_dataset_file = File.new("data/hamster_carcinogenicity.test.csv","r")
      
      
      #@prediction_feature = "http://local-ot/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
      #@prediction_feature = "http://local-ot/dataset/1/feature/hamster_carcinogenicity"
    end
  end
  
  class MajorityHamsterTrainingTest < HamsterTrainingTest
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end
  
  class LazarHamsterTrainingTest < HamsterTrainingTest
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  ########################################################################################################  

  class HamsterCrossvalidation < CrossValidation
    def initialize
      #@dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
      @dataset_file = File.new("data/hamster_carcinogenicity.csv","r")
      
      #@prediction_feature = "http://local-ot/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
      #@prediction_feature = "http://local-ot/dataset/1/feature/hamster_carcinogenicity"
      @num_folds = 10
    end
  end
  
  class MajorityHamsterCrossvalidation < HamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end

  class LazarHamsterCrossvalidation < HamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  ########################################################################################################  

  class ISTHamsterCrossvalidation < CrossValidation
    def initialize
      @dataset_uri = "http://ot-test.in-silico.ch/dataset/1"
      @prediction_feature = "http://ot-test.in-silico.ch/dataset/1/feature/Hamster%20Carcinogenicity"
    end
  end
  
  class MajorityISTHamsterCrossvalidation < ISTHamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end
  
  class LazarISTHamsterCrossvalidation < ISTHamsterCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  class ISTLazarISTHamsterCrossvalidation < ISTHamsterCrossvalidation
    def initialize
      @algorithm_uri = "http://ot-test.in-silico.ch/algorithm/lazar"
      @algorithm_params = "feature_generation_uri=http://ot-test.in-silico.ch/algorithm/fminer/bbrc"
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

  class ISTRatLiverCrossvalidation < CrossValidation
    def initialize
      @dataset_uri = "http://webservices.in-silico.ch/dataset/26"
      @prediction_feature = "http://toxcreate.org/feature#chr_rat_liver_proliferativelesions"
    end
  end
  
  class MajorityISTRatLiverCrossvalidation < ISTRatLiverCrossvalidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
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


  class ISTHamsterModel < ModelValidation
    def initialize
      @model_uri = "http://ot-test.in-silico.ch/model/2"
      @test_dataset_uri = "http://opentox.informatik.uni-freiburg.de/dataset/167"
      @test_target_dataset_uri = "http://ot-test.in-silico.ch/dataset/1"
    end
  end
  
  ########################################################################################################
  
  class LR_AmbitCacoModel < ModelValidation
    def initialize
#      @model_uri = "http://apps.ideaconsult.net:8080/ambit2/model/33"
#      @test_dataset_uri = "http://apps.ideaconsult.net:8080/ambit2/dataset/R545"
      #@prediction_feature=http://apps.ideaconsult.net:8080/ambit2/feature/22200
      
      @model_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/model/33"
      @test_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R545"
      
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
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/regr/algorithm")
      super
    end
  end
  
  ########################################################################################################
  
  class NtuaModel < ModelValidation
    def initialize
      @model_uri = "http://opentox.ntua.gr:4000/model/0d8a9a27-3481-4450-bca1-d420a791de9d"
      @test_dataset_uri = "http://apps.ideaconsult.net:8080/ambit2/dataset/54"
      #@prediction_feature=http://apps.ideaconsult.net:8080/ambit2/feature/22200
    end
  end
  
  ########################################################################################################
  
  class TumModel < ModelValidation
    def initialize
      @model_uri = "http://opentox-dev.informatik.tu-muenchen.de:8080/OpenTox-sec/sec/model/TUMOpenToxModel_M5P_5"
      @test_dataset_uri = "http://apps.ideaconsult.net:8080/ambit2/dataset/99488"
    end
  end  
  
  ########################################################################################################
  
  class AmbitModelValidation < ModelValidation
    def initialize
      @model_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/model/39319"
      #@model_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/model/29139"
      @test_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401577?max=3"
    end
  end    
  
  class AmbitBursiModelValidation < ModelValidation
    def initialize
      @model_uri =  "https://ambit.uni-plovdiv.bg:8443/ambit2/model/35194"
      @test_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401577"
    end
  end
  
  class AmbitAquaticModelValidation < ModelValidation
    def initialize
      @model_uri =  "http://apps.ideaconsult.net:8080/ambit2/model/130668"
      @test_dataset_uri = "http://apps.ideaconsult.net:8080/ambit2/dataset/186293?feature_uris[]=http://apps.ideaconsult.net:8080/ambit2/feature/430904&feature_uris[]=http://apps.ideaconsult.net:8080/ambit2/feature/430905"
      @prediction_feature = "http://apps.ideaconsult.net:8080/ambit2/feature/430905"
    end
  end  
  
  class AmbitTrainingTest < TrainingTestValidation
    def initialize
      @training_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401560"
      #@training_dataset_uri = "http://opentox.informatik.uni-freiburg.de/dataset/317"
      @test_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401560"
      @prediction_feature = "https://ambit.uni-plovdiv.bg:8443/ambit2/feature/22190"
      @algorithm_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/algorithm/LR"
    end
  end   
  
  class AmbitBursiTrainingTest < TrainingTestValidation
    def initialize
      @test_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401577"
      @training_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401577"
      @prediction_feature = "https://ambit.uni-plovdiv.bg:8443/ambit2/feature/26221"
      @algorithm_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/algorithm/J48"
    end
  end    
  
  class AmbitJ48TrainingTest < TrainingTestValidation
    def initialize
      @test_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/39914"
      @training_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/39914"
      @prediction_feature = "https://ambit.uni-plovdiv.bg:8443/ambit2/feature/221726"
      @algorithm_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/algorithm/J48"
    end
  end  
  
  class AmbitTrainingTestSplit < SplitTestValidation
    def initialize
      #@model_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/model/29139"
      @dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401560"
      #@test_dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401560"
      @prediction_feature = "https://ambit.uni-plovdiv.bg:8443/ambit2/feature/22190"
      @algorithm_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/algorithm/LR"
    end
  end  
  
  class AmbitBursiTrainingTestSplit < SplitTestValidation
    def initialize
      @dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/R401577"
      @prediction_feature = "https://ambit.uni-plovdiv.bg:8443/ambit2/feature/26221"
      @algorithm_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/algorithm/J48"
    end
  end    
  
  class AmbitJ48TrainingTestSplit < SplitTestValidation
    def initialize
      @dataset_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/dataset/39914"
      @prediction_feature = "https://ambit.uni-plovdiv.bg:8443/ambit2/feature/221726"
      @algorithm_uri = "https://ambit.uni-plovdiv.bg:8443/ambit2/algorithm/J48"
    end
  end    
  
  
   ########################################################################################################
   
  class HamsterTrainingTest < TrainingTestValidation
    def initialize
#      @test_target_dataset_file = File.new("data/hamster_carcinogenicity.yaml","r")
#      @training_dataset_file = File.new("data/hamster_carcinogenicity.train.yaml","r")
#      @test_dataset_file = File.new("data/hamster_carcinogenicity.test.yaml","r")
      
      @test_target_dataset_file = File.new("data/hamster_carcinogenicity.csv","r")
      @training_dataset_file = File.new("data/hamster_carcinogenicity.train.csv","r")
      @test_dataset_file = File.new("data/hamster_carcinogenicity.test.csv","r")
      
      
      #@prediction_feature = "http://local-ot/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)"
      #@prediction_feature = "http://local-ot/dataset/1/feature/hamster_carcinogenicity"
    end
  end
  
  class MajorityHamsterTrainingTest < HamsterTrainingTest
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end
  
  ########################################################################################################
  
  class RepdoseSplit < SplitTestValidation
    def initialize
      @dataset_file = File.new("data/repdose_classification.csv","r")
    end
  end
  
  class LazarRepdoseSplit < RepdoseSplit
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  class MajorityRepdoseSplit < RepdoseSplit
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
      super
    end
  end  
  
    ########################################################################################################
  
  class RepdoseCrossValidation < CrossValidation
    def initialize
      @dataset_file = File.new("data/repdose_classification.csv","r")
    end
  end
  
  class LazarRepdoseCrossValidation < RepdoseCrossValidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")
      @algorithm_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
      super
    end
  end
  
  class MajorityRepdoseCrossValidation < RepdoseCrossValidation
    def initialize
      @algorithm_uri = File.join(CONFIG[:services]["opentox-majority"],"/class/algorithm")
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
      
      "8a" => [ LazarIrisCrossvalidation ],
      "8b" => [ MajorityIrisCrossvalidation ],
      
      "9a" => [ ISTLazarISTIrisCrossvalidation ],
      
      "10a" => [ ISTLazarISTEpaCrossvalidation ],
      
      "11b" => [ MajorityISTRatLiverCrossvalidation ],
      
      "12" => [ LazarHamsterBootstrapping, MajorityHamsterBootstrapping ],
      "12a" => [ LazarHamsterBootstrapping ],
      "12b" => [ MajorityHamsterBootstrapping ],
      
      "13a" =>  [ LazarEPAFHMSplit ],
      "13b" =>  [ MajorityEPAFHMSplit ],
      
      "14a" =>  [ LazarEPAFHMCrossvalidation ],
      "14b" =>  [ MajorityEPAFHMCrossvalidation ],
      
      "15a" =>  [ NtuaModel ],
      
      "16" => [ LazarRepdoseSplit, MajorityRepdoseSplit ],
      "16a" => [ LazarRepdoseSplit ],
      "16b" => [ MajorityRepdoseSplit ],      
      
      "17" => [ LazarRepdoseCrossValidation, MajorityRepdoseCrossValidation ],
      "17a" => [ LazarRepdoseCrossValidation ],
      "17b" => [ MajorityRepdoseCrossValidation ],
      
      "18a" =>  [ TumModel ],
      
      "19a" =>  [ AmbitModelValidation ],
      "19b" =>  [ AmbitTrainingTest ],
      "19c" =>  [ AmbitTrainingTestSplit ],
      "19d" => [ AmbitBursiTrainingTest ],
      "19e" => [ AmbitBursiModelValidation ],
      "19f" => [ AmbitBursiTrainingTestSplit ],
      "19g" => [ AmbitJ48TrainingTest ],
      "19h" => [ AmbitJ48TrainingTestSplit ],
      "19i" => [ AmbitAquaticModelValidation ],
      
      "20" => [ ISTHamsterModel ],
      
      
      
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