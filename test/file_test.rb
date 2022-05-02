require 'logger'
require_relative 'test_helper'

describe RemoteFiles::File do
  before do
    @s3 = RemoteFiles.add_store(:s3, :class => RemoteFiles::MockStore, :primary => true)
    @cf = RemoteFiles.add_store(:cf, :class => RemoteFiles::MockStore)

    @file = RemoteFiles::File.new('identifier')
  end

  describe '#logger' do
    it 'defaults to the configuration logger' do
      configuration_logger = Logger.new($stdout)
      configuration = RemoteFiles.configure(:test)
      configuration.logger = configuration_logger

      file = RemoteFiles::File.new('identifier', :configuration => :test)
      file.logger.must_equal configuration_logger

      new_logger = Logger.new($stdout)
      file.logger = new_logger
      file.logger.must_equal new_logger
    end

    it 'is settable at initialization' do
      logger = Logger.new($stdout)
      file = RemoteFiles::File.new('identifier', :logger => logger)
      file.logger.must_equal logger
    end
  end

  describe '#stored?' do
    it 'should return true if the file is stored anywhere' do
      @file.stored_in << :s3
      @file.stored?.must_equal(true)
    end

    it 'should return false if the file is not stored anywhere' do
      @file.stored_in.clear
      @file.stored?.must_equal(false)
    end
  end

  describe '#stored_everywhere?' do
    it 'should return false if the file is not stored anywhere' do
      @file.stored_in.clear
      @file.stored_everywhere?.must_equal(false)
    end

    it 'should return false if the file only is stored in some of the stores' do
      @file.stored_in.replace([:s3])
      @file.stored_everywhere?.must_equal(false)
    end

    it 'should return true if the file is stored in all stores' do
      @file.stored_in.replace([:s3, :cf])
      @file.stored_everywhere?.must_equal(true)
    end
  end

  describe '#stores' do
    it 'should give an array of stores where the file is stored' do
      @file.stored_in.replace([:s3])
      @file.stores.must_equal([@s3])
    end
  end

  describe '#missing_stores' do
    it 'should give an array of stores where the file is not stored' do
      @file.stored_in.replace([:s3])
      @file.missing_stores.must_equal([@cf])
    end
  end

  describe '#url' do
    before do
      @s3.stubs(:url).returns('s3_url')
      @cf.stubs(:url).returns('cf_url')
    end

    describe 'with no arguments' do
      it 'should return the url on the primary store' do
        @file.url.must_equal('s3_url')
      end
    end

    describe 'with a store identifier' do
      it 'should return the url from that store' do
        @file.url(:cf).must_equal('cf_url')
      end
    end
  end

  describe '#current_url' do
    it 'should return the url from the first store where the file is currently stored' do
      @s3.stubs(:url).returns('s3_url')
      @cf.stubs(:url).returns('cf_url')

      @file.stored_in.replace([:s3])
      @file.current_url.must_equal('s3_url')

      @file.stored_in.replace([:cf])
      @file.current_url.must_equal('cf_url')

      @file.stored_in.replace([:cf, :s3])
      @file.current_url.must_equal('s3_url')

      @file.stored_in.replace([])
      @file.current_url.must_be_nil
    end

    describe '::from_url' do
      it 'should return a file from the first store that matches' do
        url = 'http://something'
        @cf.expects(:file_from_url).with(url, :configuration => :default).returns(@file)
        assert_equal @file, RemoteFiles::File.from_url(url)
      end
    end
  end

  describe '#delete_now!' do
    it 'asks the configuration to delete the file' do
      @file.configuration.expects(:delete_now!).with(@file).returns(true)
      @file.delete_now!
    end
  end

  describe '#delete!' do
    it 'asks the configuration to delete the file' do
      @file.configuration.expects(:delete!).with(@file).returns(true)
      @file.delete!
    end
  end

  describe '#retrieve!' do
    before do
      @file_with_content = RemoteFiles::File.new('identifier', :content => 'content', :content_type => 'content_type', :populate_stored_in => nil)

      @store = stub
      @file.stubs(:stores).returns([@store])
    end

    describe 'when the file is found' do
      before do
        @store.expects(:retrieve!).returns(@file_with_content)
      end

      it 'fills in the content and content_type' do
        @file.content.must_be_nil
        @file.content_type.must_be_nil

        @file.retrieve!

        @file.content.must_equal 'content'
        @file.content_type.must_equal 'content_type'
      end

      it 'does not fill in stored_in' do
        @file.stored_in.must_equal []

        @file.retrieve!

        @file.stored_in.must_equal []
      end
    end

    describe 'when the file is not found' do
      before do
        @store.expects(:retrieve!).returns(nil)
      end

      it 'raises a NotFoundError' do
        proc { @file.retrieve! }.must_raise(RemoteFiles::NotFoundError)
      end
    end

    describe 'populate_stored_in is set' do
      before do
        @file_with_content = RemoteFiles::File.new('identifier', :content => 'content', :content_type => 'content_type', :populate_stored_in => true)
        @file.stubs(:stored_in).returns([@store])
      end

      describe 'when the file is found' do
        before do
          @store.expects(:retrieve!).returns(@file_with_content)
        end

        it 'fills in the content, content_type, and stored_in' do
          @file.content.must_be_nil
          @file.content_type.must_be_nil
          @file.populate_stored_in.must_be_nil

          @file.retrieve!

          @file.content.must_equal 'content'
          @file.content_type.must_equal 'content_type'
          @file.stored_in.must_equal [@store]
        end
      end

      describe 'when the file is not found' do
        before do
          @store.expects(:retrieve!).returns(nil)
        end

        it 'raises a NotFoundError' do
          proc { @file.retrieve! }.must_raise(RemoteFiles::NotFoundError)
        end
      end
    end
  end
end
