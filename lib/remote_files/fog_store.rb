require 'remote_files/abstract_store'
require 'fog'

module RemoteFiles
  class FogStore < AbstractStore
    AWS_SUBDOMAIN = /^(?:[a-z]|\d(?!\d{0,2}(?:\d{1,3}){3}$))(?:[a-z0-9\.]|(?![\-])|\-(?![\.])){1,61}[a-z0-9]$/

    def store!(file)
      success = directory.files.create(
        :body         => file.content,
        :content_type => file.content_type,
        :key          => file.identifier,
        :public       => options[:public]
      )

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
        path = identifier.split("/").map {|str| Fog::AWS.escape(str) }.join("/")

        if directory_name =~ AWS_SUBDOMAIN
          "https://#{directory_name}.s3.amazonaws.com/#{path}"
        else
          "https://s3.amazonaws.com/#{directory_name}/#{path}"
        end
      when 'Rackspace'
        path = Fog::Rackspace.escape(identifier, '/')

        "https://storage.cloudfiles.com/#{directory_name}/#{path}"
      else
        raise "#{self.class.name}#url was not implemented for the #{options[:provider]} provider"
      end
    end

    def url_matcher
      @url_matcher ||= case options[:provider]
      when 'AWS'
        if directory_name =~ AWS_SUBDOMAIN
          /https?:\/\/#{directory_name}\.s3[^\.]*.amazonaws.com\/(.*)/
        else
          /https?:\/\/s3[^\.]*.amazonaws.com\/#{directory_name}\/(.*)/
        end
      when 'Rackspace'
        /https?:\/\/storage.cloudfiles.com\/#{directory_name}\/(.*)/
      else
        raise "#{self.class.name}#url_matcher was not implemented for the #{options[:provider]} provider"
      end
    end

    def delete!(identifier)
      connection.delete_object(directory.key, identifier)
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
  end
end
