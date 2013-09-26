# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'remote_files/version'

Gem::Specification.new do |gem|
  gem.name          = 'remote_files'
  gem.version       = RemoteFiles::VERSION
  gem.authors       = ['Mick Staugaard']
  gem.email         = ['mick@staugaard.com']
  gem.description   = 'A library for uploading files to multiple remote storage backends like Amazon S3 and Rackspace CloudFiles.'
  gem.summary       = 'The purpose of the library is to implement a simple interface for uploading files to multiple backends and to keep the backends in sync, so that your app will keep working when one backend is down.'
  gem.homepage      = 'https://github.com/zendesk/remote_files'
  gem.license = "Apache License Version 2.0"

  gem.files         = Dir.glob('{lib,test}/**/*') + ['README.md']
  gem.test_files    = gem.files.grep(/test\//)
  gem.require_paths = ['lib']

  gem.add_dependency 'fog', '~> 1.15'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'minitest', '~> 3.4.0'
  gem.add_development_dependency 'debugger' if RUBY_VERSION < '2.0'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'resque'
end
