module RemoteFiles
  class AbstractStore
    attr_reader :identifier

    def initialize(identifier)
      @identifier = identifier
    end

    def options
      @options ||= {}
    end

    def []=(name, value)
      options[name] = value
    end

    def to_sym
      @identifier.to_sym
    end

    def directory_name
      raise "You need to implement #{self.class.name}:#directory_name"
    end

    def files(prefix = '')
      raise "You need to implement #{self.class.name} #files"
    end

    def copy_to_store!(file, target_store)
      raise "You need to implement #{self.class.name} #copy_to_store!"
    end

    def store!(file)
      raise "You need to implement #{self.class.name}#store!"
    end

    def retrieve!(identifier)
      raise "You need to implement #{self.class.name}#retrieve!"
    end

    def delete!(identifier)
      raise "You need to implement #{self.class.name}#delete!"
    end

    def url(identifier)
      raise "You need to implement #{self.class.name}#url"
    end

    def url_matcher
      raise "You need to implement #{self.class.name}:#url_matcher"
    end

    def read_only?
      options[:read_only] == true
    end

    def read_delete_only?
      options[:read_delete_only] == true
    end

    def file_from_url(url, options = {})
      matched = url_matcher.match(url)

      return nil unless matched

      file_identifier = CGI.unescape(matched[1])

      RemoteFiles::File.new(file_identifier, options.merge(:stored_in => [self]))
    end
  end
end
