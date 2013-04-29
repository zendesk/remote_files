require 'pathname'
require 'fileutils'

# This is good for use in deveopment

module RemoteFiles
  class FileStore < AbstractStore

    def directory
      @directory ||= Pathname.new(options[:directory]).tap do |dir|
        dir.mkdir unless dir.exist?
        raise "#{dir} is not a directory" unless dir.directory?
      end
    end

    def store!(file)
      file_name = directory + file.identifier

      FileUtils.mkdir_p(file_name.parent)

      file_name.open('wb') do |f|
        if file.content.respond_to?(:read)
          while blk = file.content.read(2048)
            f << blk
          end
        else
          f.write(file.content)
          # what about content-type?
        end
      end
    end

    def retrieve!(identifier)
      content = (directory + identifier).read

      RemoteFiles::File.new(identifier,
        :content      => content,
        :stored_in    => [self]
        # what about content-type? maybe use the mime-types gem?
      )
    rescue Errno::ENOENT
      raise NotFoundError, $!.message, $!.backtrace
    end

    def delete!(identifier)
      (directory + identifier).delete
    rescue Errno::ENOENT
      raise NotFoundError, $!.message, $!.backtrace
    end

    def url(identifier)
      "file://localhost#{directory + identifier}"
    end

    def url_matcher
      @url_matcher ||= /file:\/\/localhost#{directory}\/(.*)/
    end

    def directory_name
      options[:directory].to_s
    end
  end
end
