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

  # IMPORTANT: fog ~v1.37 requires mime-types-data gem, and that onesupports ruby 2.0.x only.
  # https://github.com/mime-types/mime-types-data/blob/master/mime-types-data.gemspec#L19
  gem.add_dependency 'fog', '1.15.0'
end
