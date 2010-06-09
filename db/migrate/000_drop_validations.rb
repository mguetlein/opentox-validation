
class DropValidations < ActiveRecord::Migration
  def self.up
   # drop_table :validations if table_exists? :validations
   # drop_table :crossvalidations if table_exists? :crossvalidations
  end

  def self.down
    #drop_table :validations if table_exists? :validations
    #drop_table :crossvalidations if table_exists? :crossvalidations
  end
end

