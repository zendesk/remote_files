# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'remote_files/version'

Gem::Specification.new 'remote_files', RemoteFiles::VERSION do |gem|
  gem.authors       = ['Mick Staugaard']
  gem.email         = ['mick@staugaard.com']
  gem.description   = 'A library for uploading files to multiple remote storage backends like Amazon S3 and Rackspace CloudFiles.'
  gem.summary       = 'The purpose of the library is to implement a simple interface for uploading files to multiple backends and to keep the backends in sync, so that your app will keep working when one backend is down.'
  gem.homepage      = 'https://github.com/zendesk/remote_files'
  gem.license       = 'Apache License Version 2.0'

  gem.files         = `git ls-files lib README.md`.split("\n")

  # NOTE: fog >1.32 requires mime-types gem, and required mime-types-data supports ruby 2.0 only.
  gem.add_dependency 'fog', '1.32.0'
  gem.add_dependency 'fog-core', '1.32.0'

  # Required by Ruby v1.9.3
  gem.add_dependency 'fog-google', '0.0.7'
  gem.add_dependency 'mime-types', '2.6.1'
  gem.add_dependency 'net-ssh', '2.9.2'
  gem.add_dependency 'net-ssh', '2.9.2'
end
