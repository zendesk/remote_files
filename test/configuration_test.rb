require 'logger'
require_relative 'test_helper'
require 'remote_files/mock_store'

describe RemoteFiles::Configuration do
  before do
    @configuration = RemoteFiles.configure(:test)
    @file = RemoteFiles::File.new('file', :configuration => :test, :content => 'content', :content_type => 'text/plain', :last_update_ts => Time.utc(1970, 4, 22), :errors => [])
    @mock_store1 = @configuration.add_store(:mock1, :class => RemoteFiles::MockStore)
    @mock_store2 = @configuration.add_store(:mock2, :class => RemoteFiles::MockStore, :read_only => false)
  end

  describe '#logger' do
    it 'defaults to RemoteFiles.logger' do
      @configuration.logger = nil
      logger = Logger.new($stdout)
      RemoteFiles.logger = logger
      configuration_logger = @configuration.logger
      RemoteFiles.logger = nil

      configuration_logger.must_equal logger

      new_logger = Logger.new($stdout)

      @configuration.logger = new_logger
      @configuration.logger.must_equal new_logger

      @configuration.logger = nil
      @configuration.logger.must_be_nil
    end
  end

  describe '#add_store' do
    describe 'when adding a non-primary store' do
      before { @non_primary_store = @configuration.add_store(:primary) }

      it 'should add it to the tail of the list of stores' do
        @configuration.stores.must_equal([@mock_store1, @mock_store2, @non_primary_store])
      end
    end

    describe 'when adding a primary store' do
      before { @primary_store = @configuration.add_store(:primary, :primary => true) }

      it 'should add it to the head of the list of stores' do
        @configuration.stores.must_equal([@primary_store, @mock_store1, @mock_store2])
      end
    end
  end

  describe '#read_write_stores' do
    before do
      @store1 = @configuration.add_store(:store1)
      @store2 = @configuration.add_store(:store2, :primary => true)
      @read_only_store = @configuration.add_store(:read_only_store, :read_only => true)
      @store3 = @configuration.add_store(:store3, :read_only => false)
    end

    it 'should return only read write stores' do
      @configuration.read_write_stores.must_equal([@store2, @mock_store1, @mock_store2, @store1, @store3])
    end
  end

  describe '#read_only_stores' do
    before do
      @store1 = @configuration.add_store(:store1)
      @store2 = @configuration.add_store(:store2, :primary => true)
      @read_only_store = @configuration.add_store(:read_only_store, :read_only => true)
      @store3 = @configuration.add_store(:store3, :read_only => false)
    end

    it 'should return only read write stores' do
      @configuration.read_only_stores.must_equal([@read_only_store])
    end
  end

  describe '#primary_store' do
    before do
      @primary_store1 = @configuration.add_store(:primary1, :primary => true)
      @primary_store2 = @configuration.add_store(:primary2, :primary => true)
    end

    it 'should return the head of the list of stores' do
      @configuration.primary_store.must_equal(@primary_store2)
    end
  end

  describe '#lookup_store' do
    before do
      @primary_store = @configuration.add_store(:primary, :primary => true)
    end

    it 'should find the store my identifier' do
      @configuration.lookup_store(:mock1).must_equal(@mock_store1)
      @configuration.lookup_store(:mock2).must_equal(@mock_store2)
      @configuration.lookup_store(:primary).must_equal(@primary_store)
      @configuration.lookup_store(:unknown).must_be_nil
    end
  end

  describe '#store_once!' do
    before do
      @configuration.clear
      @file.stored_in.replace([])

      @mock_store1 = @configuration.add_store(:mock1, :class => RemoteFiles::MockStore)
      @read_only_store = @configuration.add_store(:read_only_store, :class => RemoteFiles::MockStore, :read_only => true)
      @mock_store2 = @configuration.add_store(:mock2, :class => RemoteFiles::MockStore, :read_only => false)
    end

    describe 'when the first store succeeds' do
      before do
        @configuration.store_once!(@file)
      end

      it 'should only store the file in the first store' do
        @mock_store1.data['file'].must_equal(:content => 'content', :content_type => 'text/plain', :last_update_ts => @file.last_update_ts)
        @mock_store2.data['file'].must_be_nil
      end

      it 'should not add any errors into the file' do
        @file.errors.length.must_equal 0
      end
    end

    describe 'when the first store fails' do
      before do
        @log = StringIO.new
        @file.logger = Logger.new(@log)
        @mock_store1.expects(:store!).with(@file).raises(RemoteFiles::Error)
        @configuration.store_once!(@file)
      end

      it 'should only store the file in the second editable store' do
        @read_only_store.expects(:store!).never

        @mock_store1.data['file'].must_be_nil
        @mock_store2.data['file'].must_equal(:content => 'content', :content_type => 'text/plain', :last_update_ts => @file.last_update_ts)
      end

      it 'logs that the first store failed' do
        @log.string.must_match(/RemoteFiles::Error/)
      end

      it 'adds the errors into the file'  do
        @file.errors[0].to_s.must_match(/RemoteFiles::Error/)
      end
    end

    describe 'when configured without an errors array' do
      before do
        @file2 = RemoteFiles::File.new('file', :configuration => :test, :content => 'content', :content_type => 'text/plain', :last_update_ts => Time.utc(1970, 4, 22))
        @mock_store1.expects(:store!).with(@file2).raises(RemoteFiles::Error)
        @configuration.store_once!(@file2)
      end

      it 'errors array returns nil' do
        assert_nil @file2.errors
      end
    end

    describe 'when alls stores fail' do
      before do
        @mock_store1.expects(:store!).with(@file).raises(RemoteFiles::Error)
        @mock_store2.expects(:store!).with(@file).raises(RemoteFiles::Error)
        # should never try a readable store
        @read_only_store.expects(:store!).never
      end

      it 'should raise a RemoteFiles::Error' do
        proc { @configuration.store_once!(@file) }.must_raise(RemoteFiles::Error)
      end
    end
  end

  describe '#store!' do
    describe 'when the file is already stored in some stores' do
      before { @file.stored_in.replace([@mock_store1.identifier]) }

      it 'should not store the file' do
        @configuration.expects(:store_once!).never
        @configuration.store!(@file)
      end

      it 'should synchronize the stores' do
        RemoteFiles.expects(:synchronize_stores).with(@file)
        @configuration.store!(@file)
      end
    end

    describe 'when the file is stored in all stores' do
      before { @file.stored_in.replace([@mock_store1.identifier, @mock_store2.identifier]) }

      it 'should not store the file' do
        @configuration.expects(:store_once!).never
        @configuration.store!(@file)
      end

      it 'should not synchronize the stores' do
        RemoteFiles.expects(:synchronize_stores).never
        @configuration.store!(@file)
      end

    end

    describe 'when the file is not stored anywhere' do
      before { @file.stored_in.replace([]) }

      it 'should store the file once' do
        @file.configuration.expects(:store_once!).with(@file)
        @configuration.store!(@file)
      end

      it 'should synchronize the stores' do
        RemoteFiles.expects(:synchronize_stores).with(@file)
        @configuration.store!(@file)
      end
    end
  end

  describe '#delete_now!' do
    before do
      @read_only_store = @configuration.add_store(:read_only_store, :class => RemoteFiles::MockStore, :read_only => true)
      @file.stored_in.replace([:mock1, :read_only_store, :mock2])
    end

    it 'raises when no stored are configured' do
      @file.expects(:read_write_stores).returns([])
      e = assert_raises(RuntimeError) { @configuration.delete_now!(@file) }
      e.message.must_equal "No stores configured"
    end

    describe 'when the file is in all of stores' do
      before do
        @mock_store1.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}
        @read_only_store.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}
        @mock_store2.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}
      end

      it 'should delete the file from all editable stores' do
        @configuration.delete_now!(@file)
        @mock_store1.data.has_key?(@file.identifier).must_equal false
        @read_only_store.data.has_key?(@file.identifier).must_equal true
        @mock_store2.data.has_key?(@file.identifier).must_equal false
      end
    end

    describe 'when the file is in some of stores' do
      before do
        @mock_store2.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}
        @read_only_store.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}
        @configuration.delete_now!(@file)
      end

      it 'should delete the file from all the stores' do
        @mock_store1.data.has_key?(@file.identifier).must_equal false
        @mock_store2.data.has_key?(@file.identifier).must_equal false
      end

      it 'should not delete the file from the read only stores' do
        @read_only_store.data.has_key?(@file.identifier).must_equal true
      end
    end

    describe 'when the file is in none of stores' do
      it 'does not raise' do
        @configuration.delete_now!(@file)
        @mock_store1.data.has_key?(@file.identifier).must_equal false
        @mock_store2.data.has_key?(@file.identifier).must_equal false
      end
    end

    describe 'when there is a non-404 error' do
      it 're-raises the error' do
        @mock_store1.expects(:delete!).raises(Excon::Errors::Error)
        proc { @configuration.delete_now!(@file) }.must_raise(Excon::Errors::Error)
      end
    end

    describe 'when deleting files in parallel' do
      before do
        @read_only_store = @configuration.add_store(:read_only_store, :class => RemoteFiles::MockStore, :read_only => true)
        @file.stored_in.replace([:mock1, :read_only_store, :mock2])
      end

      it 'deletes the file from all editable stores in parallel' do
        @mock_store1.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}
        @mock_store2.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}
        @read_only_store.data[@file.identifier] = {:content_type => 'text/plain', :content => 'content'}

        @configuration.delete_now!(@file, parallel: true)

        @mock_store1.data.has_key?(@file.identifier).must_equal false
        @mock_store2.data.has_key?(@file.identifier).must_equal false
        @read_only_store.data.has_key?(@file.identifier).must_equal true
      end

      it 'raises when no stores are configured' do
        @file.expects(:read_write_stores).returns([])
        e = assert_raises(RuntimeError) { @configuration.delete_now!(@file, parallel: true) }
        e.message.must_equal "No stores configured"
      end

      it 'does not raise when all stores fail with NotFoundErrors' do
        @mock_store1.expects(:delete!).raises(RemoteFiles::NotFoundError)
        @mock_store2.expects(:delete!).raises(RemoteFiles::NotFoundError)
        @read_only_store.expects(:delete!).never

        @configuration.delete_now!(@file, parallel: true)
      end

      describe 'when there is a non-404 error' do
        it 're-raises the error' do
          @mock_store1.expects(:delete!).raises(Excon::Errors::Error)
          proc { @configuration.delete_now!(@file, parallel: true) }.must_raise(Excon::Errors::Error)
        end
      end
    end
  end

  describe '#delete!' do
    describe 'when no handler has been defined' do
      before do
        RemoteFiles.instance_variable_set(:@delete_file, nil)
      end

      it 'deletes the file' do
        @file.expects(:delete_now!)
        @configuration.delete!(@file)
      end
    end

    describe 'when a handler is defined' do
      before do
        @deleted_files = []
        RemoteFiles.delete_file { |file| @deleted_files << file }
      end

      it 'should call the handler' do
        @configuration.delete!(@file)
        @deleted_files.must_equal [@file]
      end
    end
  end

  describe '#synchronize!' do
    describe 'when the file is not stored anywhere' do
      before do
        @read_only_store = @configuration.add_store(:read_only_store, :read_only => true)
        @file.stored_in.replace([])
      end

      it 'should store the file on all editable stores' do
        @mock_store1.expects(:store!).returns(true)
        @mock_store2.expects(:store!).returns(true)
        @read_only_store.expects(:store!).never

        @configuration.synchronize!(@file)
      end
    end

    describe 'when the file is stored in some stores' do
      before { @file.stored_in.replace([@mock_store1.identifier]) }

      it 'should store the file in the remaining stores' do
        @mock_store1.expects(:store!).never
        @mock_store2.expects(:store!).with(@file).returns(true)

        @configuration.synchronize!(@file)
      end
    end

    describe 'when the file is stored everywhere' do
      before { @file.stored_in.replace([@mock_store1.identifier, @mock_store2.identifier]) }

      it 'should not do anything' do
        @mock_store1.expects(:store!).never
        @mock_store2.expects(:store!).never

        @configuration.synchronize!(@file)
      end
    end
  end

  describe '#file_from_url' do
    before do
      @file = @configuration.file_from_url('memory://mock2/foo%40bar', :foo => :bar)
      assert @file
    end

    it 'should unescape the identifier' do
      @file.identifier.must_equal "foo@bar"
    end

    it 'should return a file from this configuration' do
      @file.configuration.must_equal @configuration
    end

    it 'should pass on options' do
      @file.options[:foo].must_equal :bar
    end

    it 'returns nil if the url does not match a store' do
      file = @configuration.file_from_url('http://foo/bar', :foo => :bar)
      file.must_be_nil
    end
  end
end
