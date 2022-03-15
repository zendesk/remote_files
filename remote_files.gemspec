require './lib/remote_files/version'

Gem::Specification.new 'remote_files', RemoteFiles::VERSION do |gem|
  gem.authors       = ['Mick Staugaard']
  gem.email         = ['mick@staugaard.com']
  gem.description   = 'A library for uploading files to multiple remote storage backends like Amazon S3 and Rackspace CloudFiles.'
  gem.summary       = 'The purpose of the library is to implement a simple interface for uploading files to multiple backends and to keep the backends in sync, so that your app will keep working when one backend is down.'
  gem.homepage      = 'https://github.com/zendesk/remote_files'
  gem.license       = 'Apache License Version 2.0'

  gem.files         = `git ls-files lib README.md`.split("\n")
  gem.required_ruby_version = '>= 2.1'

  gem.add_dependency 'fog-aws', '>= 0.8.1'
  gem.add_dependency 'mime-types'
end
