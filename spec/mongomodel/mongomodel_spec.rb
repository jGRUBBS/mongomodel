require 'spec_helper'

describe MongoModel do
  after(:all) do
    MongoModel.configuration = {}
  end
  
  describe "setting a custom database configuration" do
    before(:each) do
      MongoModel.configuration = {
        'host'     => '127.0.0.1',
        'database' => 'mydb'
      }
    end
    
    it "shoulds merge configuration with defaults" do
      MongoModel.configuration.host.should == '127.0.0.1'
      MongoModel.configuration.port.should == 27017
      MongoModel.configuration.database.should == 'mydb'
    end
    
    it "establishes database connection to given database" do
      database = MongoModel.database
      connection = database.connection

      connection.primary_pool.host.should == '127.0.0.1'
      connection.primary_pool.port.should == 27017
      database.name.should == 'mydb'
    end
  end
  
  describe "setting a custom database configuration as a URI string" do
    before(:each) do
      MongoModel.configuration = "mongodb://127.0.0.2:27019/mydb"
    end
    
    it "shoulds merge configuration with defaults" do
      MongoModel.configuration.host.should == '127.0.0.2'
      MongoModel.configuration.port.should == 27019
      MongoModel.configuration.database.should == 'mydb'
    end
  end
  
  it "has a logger accessor" do
    logger = double('logger').as_null_object
    MongoModel.logger = logger
    MongoModel.logger.should == logger
  end
end
