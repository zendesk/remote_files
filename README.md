# RemoteFiles

A library for uploading files to multiple remote storage backends like Amazon S3 and Rackspace CloudFiles.

The purpose of the library is to implement a simple interface for uploading files to multiple backends
and to keep the backends in sync, so that your app will keep working when one backend is down.

## Installation

```Ruby
# Gemfile
gem 'remote_files'
gem 'fog-s3' # add fog for each provider you want to use
```

## Configuration

First you configure the storage backends you want:

```ruby
RemoteFiles.add_store(:s3, :primary => true) do |s3|
  s3[:provider] = 'AWS'

  s3[:aws_access_key_id]     = AWS_ACCESS_KEY_ID
  s3[:aws_secret_access_key] = AWS_SECRET_ACCESS_KEY

  s3[:directory] = 'my_s3_bucket'
end

RemoteFiles.add_store(:cf) do |cf|
  cf[:provider] = 'Rackspace'

  cf[:rackspace_username] = RACKSPACE_USERNAME
  cf[:rackspace_api_key]  = RACKSPACE_API_KEY

  cf[:directory] = 'my_cf_container'
end
```

By default RemoteFiles will store your files to all stores synchronously. This is probably not what you want,
so you should tell RemoteFiles how to do it asynchronously:

```ruby
class RemoteFilesSyncJob
  def initialize(identifier, stored_in)
    @file = RemoteFiles::File.new(identifier, :stored_in => stored_in)
  def

  def work
    @file.synchronize!
  end
end

RemoteFiles.synchronize_stores do |file|
  MyPreferredJobQueue.enqueue(RemoteFilesSyncJob, file.identifier, file.stored_in)
end
```

## Usage

Once everything is configured, you can store files like this:

```ruby
file = RemoteFiles::File.new(unique_file_name, :content => file_content, :content_type => content_type)
file.store!
```

This will store the file on one of the stores and then asynchronously copy the file to the remaining stores.
`RemoteFiles::File#store!` will raise a `RemoteFiles::Error` if all storage backends are down.

If you just need to store the file in a single store, the you can use `RemoteFiles::File#store_once!`. It will
behave exactly like `RemoteFiles::File#store!`, but will not asynchronously copy the file to the other stores.

## Copyright and license

Copyright 2013 Zendesk

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
