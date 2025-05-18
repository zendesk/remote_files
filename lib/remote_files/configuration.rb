require 'concurrent-ruby'

module RemoteFiles
  class Configuration
    attr_reader :name

    def initialize(name, config = {})
      @name       = name
      @stores     = []
      @stores_map = {}
      @max_delete_in_parallel = config.delete(:max_delete_in_parallel) || 10
      from_hash(config)
    end

    def logger=(logger)
      @logger = logger
    end

    def logger
      @logger ||= RemoteFiles.logger
    end

    def clear
      @stores.clear
      @stores_map.clear
    end

    def from_hash(hash)
      hash.each do |store_identifier, config|
        #symbolize_keys!
        cfg = {}
        config.each { |name, value| cfg[name.to_sym] = config[name] }
        config = cfg

        #camelize
        type = config[:type].gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase } + 'Store'

        klass = RemoteFiles.const_get(type) rescue nil
        unless klass
          require "remote_files/#{config[:type]}_store"
          klass = RemoteFiles.const_get(type)
        end

        config.delete(:type)

        add_store(store_identifier.to_sym, :class => klass, :primary => !!config.delete(:primary)) do |store|
          config.each do |name, value|
            store[name] = value
          end
        end
      end

      self
    end

    def add_store(store_identifier, options = {}, &block)
      store = (options[:class] || FogStore).new(store_identifier)
      block.call(store) if block_given?

      if options[:read_delete_only]
        store[:read_delete_only] = true
      elsif options[:read_only]
        store[:read_only] = true
      end

      if options[:primary]
        @stores.unshift(store)
      else
        @stores << store
      end

      @stores_map[store_identifier] = store
    end

    def configured?
      !@stores.empty?
    end

    def stores
      raise "You need to configure add stores to the #{name} RemoteFiles configuration" unless configured?

      @stores
    end

    def read_only_stores
      stores.select {|s| s.read_only?}
    end

    def read_write_stores
      stores.reject {|s| s.read_only? || s.read_delete_only?}
    end

    def lookup_store(store_identifier)
      @stores_map[store_identifier.to_sym]
    end

    def primary_store
      stores.first
    end

    def store_once!(file)
      return file.stored_in.first if file.stored?

      exception = nil

      read_write_stores.each do |store|
        begin
          stored = store.store!(file)
          file.stored_in << store.identifier
          break
        rescue ::RemoteFiles::Error => e
          file.logger.info(e) if file.logger
          file.errors.push(e) if file.errors
          exception = e
        end
      end

      raise exception unless file.stored?

      file.stored_in.first
    end

    def store!(file)
      store_once!(file) unless file.stored?

      RemoteFiles.synchronize_stores(file) unless file.stored_everywhere?

      true
    end

    def delete!(file)
      RemoteFiles.delete_file(file)
    end

    def delete_now!(file, parallel: false)
      exceptions = []
      stores = file.read_write_stores + file.read_delete_only_stores

      raise "No stores configured" if stores.empty?

      if parallel
        delete_in_parallel!(file, stores, exceptions)
      else
        stores.each do |store|
          begin
            store.delete!(file.identifier)
          rescue NotFoundError => e
            exceptions << e
          end
        end
      end

      raise exceptions.first if exceptions.size == stores.size # they all failed

      true
    end

    # Deletes a file from all writable stores in parallel.
    # When the file is missing the Future's value is set to NotFoundError exception.
    # Re-raises any other exceptions, but doesn't prevent concurrent requests from being executed.
    def delete_in_parallel!(file, stores, exceptions)
      pool = Concurrent::FixedThreadPool.new(@max_delete_in_parallel)

      futures = stores.map do |store|
        Concurrent::Promises.future_on(pool) do
          begin
            store.delete!(file.identifier)
          rescue NotFoundError => e
            e
          end
        end
      end

      futures.each do |future|
        result = future.value!
        exceptions << result if result.is_a?(Exception)
      end

      pool.shutdown
      pool.wait_for_termination
    end

    def synchronize!(file)
      file.missing_stores.each do |store|
        next if store.read_only? || store.read_delete_only?

        store.store!(file)
        file.stored_in << store.identifier
      end
    end

    def file_from_url(url, options = {})
      stores.each do |store|
        file = store.file_from_url(url, options.merge(:configuration => name))
        return file if file
      end

      nil
    end
  end
end
