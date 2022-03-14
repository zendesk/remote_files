require 'fog/aws'

module RemoteFiles
  class FogStore < AbstractStore
    MULTIPART_MAX_PARTS = 10000
    MULTIPART_MIN_SIZE = 5 * 1024 * 1024

    def store!(file)
      success = directory.files.create(store_options(file))

      raise RemoteFiles::Error unless success

      true
    rescue Fog::Errors::Error, Excon::Errors::Error
      raise RemoteFiles::Error, $!.message, $!.backtrace
    end

    def retrieve!(identifier)
      fog_file = directory.files.get(identifier)

      raise NotFoundError, "#{identifier} not found in #{self.identifier} store" if fog_file.nil?

      File.new(identifier,
        :content      => fog_file.body,
        :content_type => fog_file.content_type,
        :stored_in    => [self]
      )
    rescue Fog::Errors::Error, Excon::Errors::Error
      raise RemoteFiles::Error, $!.message, $!.backtrace
    end

    def url(identifier)
      case options[:provider]
      when 'AWS'
        "https://#{aws_host}/#{directory_name}/#{Fog::AWS.escape(identifier)}"
      else
        raise "#{self.class.name}#url was not implemented for the #{options[:provider]} provider"
      end
    end

    def url_matcher
      @url_matcher ||= case options[:provider]
      when 'AWS'
        /https?:\/\/s3[^\.]*.amazonaws.com\/#{directory_name}\/(.*)/
      else
        raise "#{self.class.name}#url_matcher was not implemented for the #{options[:provider]} provider"
      end
    end

    def delete!(identifier)
      if identifier.to_s.chomp.empty?
        message = "Empty identifier is not supported"
        raise RemoteFiles::Error, message
      end

      connection.delete_object(directory_name, identifier)
    rescue Fog::Errors::NotFound, Excon::Errors::NotFound
      raise NotFoundError, $!.message, $!.backtrace
    end

    def connection
      connection_options = options.dup
      connection_options.delete(:directory)
      connection_options.delete(:public)
      @connection ||= Fog::Storage.new(connection_options)
    end

    def directory_name
      options[:directory]
    end

    def directory
      @directory ||= lookup_directory || create_directory
    end

    protected

    def aws_host
      case options[:region]
      when nil, 'us-east-1'
        's3.amazonaws.com'
      else
        "s3-#{options[:region]}.amazonaws.com"
      end
    end

    def lookup_directory
      connection.directories.get(directory_name)
    end

    def create_directory
      connection.directories.new(
        :key => directory_name,
        :public => options[:public]
      ).tap do |dir|
        dir.save
      end
    end

    def store_options(file)
      store_options =
        {
          :body => file.content,
          :content_type => file.content_type,
          :key => file.identifier,
          :public => options[:public],
          :encryption => options[:encryption]
        }
      if file.options[:multipart_chunk_size]
        raise RemoteFiles::Error.new("Only S3 supports the multipart_chunk_size option") unless options[:provider] == 'AWS'
        chunk_size = file.options[:multipart_chunk_size]
        store_options[:multipart_chunk_size] = chunk_size
        raise RemoteFiles::Error.new("Minimum chunk size is #{MULTIPART_MIN_SIZE}") if chunk_size < MULTIPART_MIN_SIZE
        if !file.content.respond_to?(:read) || !file.content.respond_to?(:size)
          raise RemoteFiles::Error.new(':content must be a stream if chunking enabled')
        end
        if file.content.size / chunk_size > MULTIPART_MAX_PARTS
          raise RemoteFiles::Error.new("Increase chunk size so that there are less then #{10000}{MULTIPART_MAX_PARTS} parts")
        end
      end
      store_options
    end
  end
end
