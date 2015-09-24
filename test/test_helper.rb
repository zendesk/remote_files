require 'bundler/setup'

require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/setup'
require 'remote_files'


require 'fog/aws'

require 'fog/core/mock'
Fog.mock!

require 'fog/rackspace'
require 'fog/rackspace/cdn'

module Fog
  module Rackspace
    class Mock
    end
  end
end

require 'fog/rackspace/mock_data'





MiniTest::Spec.class_eval do
  before do
    Fog::Mock.reset

    RemoteFiles::CONFIGURATIONS.values.each do |conf|
      conf.clear
    end

    RemoteFiles.synchronize_stores do |file|
    end

    RemoteFiles.delete_file do |file|
    end
  end
end
