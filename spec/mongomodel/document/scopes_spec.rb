require 'spec_helper'

module MongoModel
  describe Document do
    before(:all) do
      class << MongoModel::Document
        public :with_scope, :with_exclusive_scope
        
        def should_find_with(hash)
          should_receive(:_find).with(hash)
        end
      end
    end
    
    describe "#with_scope" do
      define_class(:Article, Document) do
        property :title, String
        property :author, String
      end
      
      it "should deep merge finder options within block" do
        Article.should_find_with({
          :conditions => { :title => 'Hello World', :author => 'Editor' },
          :limit => 10, :order => 'title ASC'
        })
        
        Article.with_scope(:find => { :conditions => { :title => 'Hello World' }, :limit => 10 }) do
          Article.find(:all, :conditions => { :author => 'Editor' }, :order => 'title ASC')
        end
      end
      
      it "should cascade multiple scopes" do
        Article.should_find_with({
          :conditions => { :title => 'Hello World', :author => 'Editor' },
          :limit => 10, :order => 'title ASC', :select => :title
        })
        
        Article.with_scope(:find => { :conditions => { :title => 'Hello World' }}) do
          Article.with_scope(:find => { :select => :title, :order => 'title ASC' }) do
            Article.find(:all, :conditions => { :author => 'Editor' }, :limit => 10)
          end
        end
      end
    end
    
    describe "#with_exclusive_scope" do
      define_class(:Article, Document) do
        property :title, String
        property :author, String
      end
      
      it "should deep merge finder options within block" do
        Article.should_find_with({
          :conditions => { :title => 'Hello World', :author => 'Editor' },
          :limit => 10, :order => 'title ASC'
        })
        
        Article.with_exclusive_scope(:find => { :conditions => { :title => 'Hello World' }, :limit => 10 }) do
          Article.find(:all, :conditions => { :author => 'Editor' }, :order => 'title ASC')
        end
      end
      
      it "should not cascade non-exclusive scopes" do
        Article.should_find_with({
          :conditions => { :author => 'Editor' },
          :limit => 10, :order => 'title ASC', :select => :title
        })
        
        Article.with_scope(:find => { :conditions => { :title => 'Hello World' }}) do
          Article.with_exclusive_scope(:find => { :select => :title, :order => 'title ASC' }) do
            Article.find(:all, :conditions => { :author => 'Editor' }, :limit => 10)
          end
        end
      end
    end
    
    describe "#default_scope" do
      define_class(:User, Document) do
        property :name, String
        property :age, Integer
        
        default_scope :conditions => { :age.gt => 18 }
      end
      
      it "should merge with other scopes" do
        User.should_find_with(:conditions => { :age.gt => 18 })
        User.find(:all)
      end
      
      it "should be overridable using #with_exclusive_scope" do
        User.should_find_with({})
        User.with_exclusive_scope({}) do
          User.find(:all)
        end
      end
    end
    
    describe "#named_scope" do
      define_class(:Post, Document) do
        property :title, String
        property :published, Boolean
        property :created_at, Time
        
        named_scope :published, :conditions => { :published => true }
        named_scope :latest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
        named_scope :exclusive, :exclusive => true
      end
      
      define_class(:SpecialPost, :Post)
      
      it "should create scope methods" do
        Post.published.options_for(:find).should == { :conditions => { :published => true} }
        Post.latest(5).options_for(:find).should == { :limit => 5, :order => 'created_at DESC' }
        Post.exclusive.options_for(:find).should == {}
      end
      
      it "should find using scope options" do
        Post.should_find_with(:conditions => { :published => true })
        Post.published.find(:all)
        
        Post.should_find_with(:limit => 5, :order => 'created_at DESC')
        Post.latest(5).find(:all)
      end
      
      it "should find by id using scope conditions" do
        @post1 = Post.create(:id => 'post-1', :published => true)
        @post2 = Post.create(:id => 'post-2', :published => false)
        
        Post.published.find('post-1').should == @post1
        lambda { Post.published.find('post-2') }.should raise_error(DocumentNotFound)
      end
      
      it "should count using scope options" do
        8.times { Post.create(:published => true) }
        3.times { Post.create(:published => false) }
        
        Post.count.should == 11
        Post.published.count.should == 8
      end
      
      it "should be chainable" do
        Post.should_find_with(:conditions => { :published => true }, :limit => 5, :order => 'created_at DESC')
        Post.published.latest(5).all
      end
      
      it "should inherit named scopes from parent classes" do
        SpecialPost.published.options.should == Post.published.options
      end
      
      describe "an exclusive scope" do
        it "should override non-exclusive scopes" do
          Post.should_find_with({})
          Post.published.exclusive.all
        end
      end
      
      describe "#scoped" do
        it "should create scopes on-the-fly" do
          Post.should_find_with(:conditions => { :title => /^\d+/ })
          Post.scoped(:conditions => { :title => /^\d+/ }).all
        end
      end
    end
  end
  
  module DocumentExtensions
    describe Scope do
      before(:each) do
        @model = mock('Model')
      end
    
      it "should be initializable with options" do
        scope = Scope.new(@model, :find => { :conditions => { :foo => 'bar' } })
        scope.options.should == { :find => { :conditions => { :foo => 'bar' } } }
      end
    
      it "should deep merge options to create new scopes" do
        original = Scope.new(@model, :find => { :conditions => { :foo => 'bar' } })
        merged = original.merge(:find => { :conditions => { :baz => 123 }, :limit => 5 })
      
        original.options.should == { :find => { :conditions => { :foo => 'bar' } } }
        merged.options.should == { :find => { :conditions => { :foo => 'bar', :baz => 123 }, :limit => 5 } }
      end
    
      it "should deep merge options to update an existing scope" do
        scope = Scope.new(@model, :find => { :conditions => { :foo => 'bar' } })
        merged = scope.merge!(:find => { :conditions => { :baz => 123 }, :limit => 5 })
      
        merged.should == scope
        scope.options.should == { :find => { :conditions => { :foo => 'bar', :baz => 123 }, :limit => 5 } }
      end
    
      it "should have find options" do
        scope = Scope.new(@model, :find => { :conditions => { :foo => 'bar' } })
        scope.options_for(:find).should == { :conditions => { :foo => 'bar' } }
      end
    
      it "should have default find options" do
        scope = Scope.new(@model)
        scope.options_for(:find).should == {}
      end
    end
  end
end