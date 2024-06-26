require_relative 'test_helper'
require 'remote_files/resque_job'

describe RemoteFiles::ResqueJob do
  describe 'loading the implementation file' do
    before do
      @file = RemoteFiles::File.new('identifier',
        :content_type => 'text/plain',
        :content      => 'content',
        :stored_in    => [:s3],
        :foo          => :bar
      )

      load 'remote_files/resque_job.rb'
    end

    it 'should setup the right synchronize_stores hook' do
      Resque.expects(:enqueue).with(RemoteFiles::ResqueJob,
        :identifier    => 'identifier',
        :content_type  => 'text/plain',
        :stored_in     => [:s3],
        :foo           => :bar,
        :configuration => :default,
        :populate_stored_in => nil,
        :_action       => :synchronize,
        :last_update_ts => nil,
        :errors => nil
      )

      RemoteFiles.synchronize_stores(@file)
    end

    it 'should setup the right delete_file hook' do
      Resque.expects(:enqueue).with(RemoteFiles::ResqueJob,
        :identifier    => 'identifier',
        :content_type  => 'text/plain',
        :stored_in     => [:s3],
        :foo           => :bar,
        :configuration => :default,
        :populate_stored_in => nil,
        :_action       => :delete,
        :last_update_ts => nil,
        :errors => nil
      )

      RemoteFiles.delete_file(@file)
    end

  end

  describe "running the job" do
    before do
      @options = {
        :identifier   => 'identifier',
        :content_type => 'text/plain',
        :stored_in    => [:s3],
        :foo          => :bar
      }

      @file = stub

      RemoteFiles::File.expects(:new).with('identifier',
        :content_type => 'text/plain',
        :stored_in    => [:s3],
        :foo          => :bar
      ).returns(@file)
    end

    it 'should call #synchronize! on the reconstructed file when asked to' do
      @file.expects(:synchronize!)

      RemoteFiles::ResqueJob.perform(@options.merge(:_action => :synchronize))
    end

    it 'should call #delete_now! on the reconstructed file when asked to' do
      @file.expects(:delete_now!)

      RemoteFiles::ResqueJob.perform(@options.merge(:_action => :delete))
    end
  end

  describe 'loading the implementation file with populate_stored_in set' do
    before do
      @file = RemoteFiles::File.new('identifier',
        :content_type => 'text/plain',
        :content      => 'content',
        :stored_in    => [:s3],
        :foo          => :bar,
        :populate_stored_in => true
      )

      load 'remote_files/resque_job.rb'
    end

    it 'should setup the right synchronize_stores hook' do
      Resque.expects(:enqueue).with(RemoteFiles::ResqueJob,
        :identifier    => 'identifier',
        :content_type  => 'text/plain',
        :stored_in     => [:s3],
        :foo           => :bar,
        :configuration => :default,
        :populate_stored_in => true,
        :_action       => :synchronize,
        :last_update_ts => nil,
        :errors => nil
      )

      RemoteFiles.synchronize_stores(@file)
    end

    it 'should setup the right delete_file hook' do
      Resque.expects(:enqueue).with(RemoteFiles::ResqueJob,
        :identifier    => 'identifier',
        :content_type  => 'text/plain',
        :stored_in     => [:s3],
        :foo           => :bar,
        :configuration => :default,
        :populate_stored_in => true,
        :_action       => :delete,
        :last_update_ts => nil,
        :errors => nil
      )

      RemoteFiles.delete_file(@file)
    end
  end

  describe "running the job with populate_stored_in set" do
    before do
      @options = {
        :identifier   => 'identifier',
        :content_type => 'text/plain',
        :stored_in    => [:s3],
        :populate_stored_in => true,
        :foo          => :bar
      }

      @file = stub

      RemoteFiles::File.expects(:new).with('identifier',
        :content_type => 'text/plain',
        :stored_in    => [:s3],
        :populate_stored_in => true,
        :foo          => :bar
      ).returns(@file)
    end

    it 'should call #synchronize! on the reconstructed file when asked to' do
      @file.expects(:synchronize!)

      RemoteFiles::ResqueJob.perform(@options.merge(:_action => :synchronize))
    end

    it 'should call #delete_now! on the reconstructed file when asked to' do
      @file.expects(:delete_now!)

      RemoteFiles::ResqueJob.perform(@options.merge(:_action => :delete))
    end
  end
end
