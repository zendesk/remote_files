module RemoteFiles
  class File
    attr_reader :content, :content_type, :identifier, :stored_in, :configuration, :populate_stored_in

    def initialize(identifier, options = {})
      known_keys = [:identifier, :stored_in, :content_type, :configuration, :content, :populate_stored_in]
      known_keys.each do |key|
        options[key] ||= options.delete(key.to_s)
      end

      @identifier    = identifier
      @stored_in     = (options[:stored_in] || []).map(&:to_sym)
      @content       = options.delete(:content)
      @content_type  = options[:content_type]
      @configuration = RemoteFiles::CONFIGURATIONS[(options[:configuration] || :default).to_sym]
      @logger        = options[:logger]
      @populate_stored_in = options[:populate_stored_in]
      @options       = options
    end

    def logger=(logger)
      @logger = logger
    end

    def logger
      @logger ||= configuration ? configuration.logger : RemoteFiles.logger
    end

    def self.from_url(url)
      RemoteFiles.default_configuration.file_from_url(url)
    end

    def options
      @options.merge(
        :identifier    => identifier,
        :stored_in     => stored_in,
        :content_type  => content_type,
        :configuration => configuration.name,
        :populate_stored_in => populate_stored_in
      )
    end

    def stored?
      !@stored_in.empty?
    end

    def stored_everywhere?
      missing_stores.empty?
    end

    def stores
      @stored_in.map { |store_id| configuration.lookup_store(store_id) }
    end

    def read_write_stores
      stores.reject(&:read_only?)
    end

    def missing_stores
      configuration.stores - stores
    end

    def url(store_identifier = nil)
      store = store_identifier ? configuration.lookup_store(store_identifier) : configuration.primary_store
      return nil unless store
      store.url(identifier)
    end

    def current_url
      prioritized_stores = configuration.stores.map(&:identifier) & @stored_in

      return nil if prioritized_stores.empty?

      url(prioritized_stores[0])
    end

    def retrieve!
      stores.each do |store|
        begin
          file = store.retrieve!(identifier)
          next unless file
          @content      = file.content
          @content_type = file.content_type
          # :populate_stored_in is a boolean
          @stored_in = file.stored_in if options.key?(:populate_stored_in) && (@options[:populate_stored_in])
          return true
        rescue Error => e
        end
      end

      raise NotFoundError
    end

    def store!
      configuration.store!(self)
    end

    def store_once!
      configuration.store_once!(self)
    end

    def synchronize!
      configuration.synchronize!(self)
    end

    def delete!
      configuration.delete!(self)
    end

    def delete
      begin
        delete!
        true
      rescue RemoteFiles::Error => e
        false
      end
    end

    def delete_now!
      configuration.delete_now!(self)
    end
  end
end
