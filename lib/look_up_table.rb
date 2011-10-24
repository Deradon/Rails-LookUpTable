# TODO
# * move Methods to different modules
# * add private/protected
# * add class_names to CacheKey per default
# * if key allready used, transform values to array
# * somehow handle "cache-overflow"
module LookUpTable
  extend ActiveSupport::Concern

  # Class methods
  module ClassMethods
    # Defining a LookUpTable
    # TODO: Usage
    def look_up_table(lut_name, options={}, &block)
      options = {
        :batch_size     => 10000,
        :read_on_init   => false,
        :skip_memcached => false,
        :sql_mode       => true
      }.merge(options)

      self.lut_proc[lut_name.to_sym]    = block
      self.lut_options[lut_name.to_sym] = options

      self.lut(lut_name) if options[:read_on_init]
    end

    # Call to a LookUpTable.
    # * Example: Tag.lut(:name, "Berlin")
    # * Returns: nil or stored objects
    def lut(name, search_by=nil)
      @@lut ||= {}
      @@lut[name.to_sym] ||= lut_read(name) || {}

      search_by ? @@lut[name.to_sym][search_by] : @@lut[name.to_sym]
    end

    # Reset complete lut if name is omitted, resets given lut otherwise.
    # HACK
    def lut_reset(name=nil)
      @@lut ||= {}

      if name
        @@lut[name.to_sym] = nil
        lut_write_cache_item(name, 0, nil) unless lut_options[:skip_memcached]
      else
        lut_keys.each { |k| lut_reset(k) }
        @@lut = {}
      end
    end

    # Reloads allready loaded LUTs.
    # Will also rewrites cache.
    def lut_reload(name=nil)
      if name
        lut_reset(name)
        lut(name)
      else
        lut_keys.each { |k| lut_reload(k) }
      end
    end

    # Init complete LUT with all keys define.
    # But won't rewrite cache if allready written!
    def lut_init(name=nil)
      if name
        lut(name)
      else
        lut_keys.each do |key|
          lut_init(key)
        end
      end

      return lut_options.keys
    end



    #private
      def lut_keys
        lut_options.keys
      end

      # lut_set_proc(lut_name, block) / lut_proc(lut_name)
      def lut_set_proc(name, block)
        lut_proc[name.to_sym] = block
      end

      def lut_proc(name = nil)
        @@lut_proc ||= {}
        (name) ? @@lut_proc[name.to_sym] : @@lut_proc
      end

      # lut_set_options(lut_name, options) / lut_options(lut_name)
      def lut_set_options(name, options)
        lut_options[name.to_sym] = options
      end

      def lut_options(name = nil)#, option=nil)
        @@lut_options ||= {}
        (name) ? @@lut_options[name.to_sym] : @@lut_options
      end

      # Reads a single lut
      # HACK
      def lut_read(name)
        return nil unless options = lut_options(name)

        if options[:skip_memcached]
          return lut_read_without_cache(name)
        else
          return lut_read_from_cache(name)
        end
      end



      ################
      ### NO-CACHE ###
      ################

      # Reads a complete from given block or generic version
      # HACK: some duplicated methods from Class.lut_write_to_cache
      def lut_read_without_cache(name)
        if lut_options(name)[:sql_mode]
          return lut_read_without_cache_sql_mode(name)
        else
          return lut_read_without_cache_no_sql_mode(name)
        end
      end

      # HACK: somehow long method
      def lut_read_without_cache_sql_mode(name)
        lut   = {}
        block = lut_proc(name)

        self.find_in_batches(:batch_size => lut_options(name)[:batch_size]) do |items|
          items.each do |item|
            if block
              block.call(lut, item)
            else
              lut[item.send(name)] = item.id
            end
          end
        end

        return lut
      end

      # HACK: ugly method_name
      def lut_read_without_cache_no_sql_mode(name)
        lut   = {}

        block = lut_proc(name)
        block.call(lut)

        return lut
      end



      #############
      ### CACHE ###
      #############

      # Cache entry for given LUT exists?
      # TODO: just check if given key exists
      def lut_cache_exists?(name)
        !lut_read_cache_item(name, 0).nil?
      end

      # Reads a complete lut from cache
      # HACK: this still looks ugly somehow
      def lut_read_from_cache(name)
        lut_write_to_cache(name) unless lut_cache_exists?(name)

        i   = 0
        lut = {}

        while item = lut_read_cache_item(name, i)
          lut.merge!(item) if item
          i += 1
        end

        return lut
      end

      # Reads a single item of a LookUpTable from Cache
      def lut_read_cache_item(name, item)
        Rails.cache.read("#{name}/#{item}")
      end

      # Write a LookUpTable into Cache
      def lut_write_to_cache(name)
        if lut_options(name)[:sql_mode]
          count = lut_write_to_cache_sql_mode(name)
        else
          count = lut_write_to_cache_no_sql_mode(name)
        end

        # HACK: Writing a \0 to terminate batch_items
        lut_write_cache_item(name, count, nil)
      end

      # HACK: somehow long method
      def lut_write_to_cache_sql_mode(name)
        batch_count = 0

        self.find_in_batches(:batch_size => lut_options(name)[:batch_size]) do |items|
          lut   = {}
          block = lut_proc(name)

          items.each do |item|
            if block
              block.call(lut, item)
            else
              lut[item.send(name)] = item.id
            end
          end

          self.lut_write_cache_item(name, batch_count, lut)
          batch_count += 1
        end

        batch_count
      end

      # HACK: somehow long method
      def lut_write_to_cache_no_sql_mode(name)
        lut         = {}
        batch_count = 0

        block = lut_proc(name)
        block.call(lut)

        keys = lut.keys

        while
          key_block = keys.slice!(0, lut_options(name)[:batch_size])
          break if key_block.empty?

          lut_block = {}
          key_block.each{|key| lut_block[key] = lut[key]}

          self.lut_write_cache_item(name, batch_count, lut_block)
          batch_count += 1
        end

        batch_count
      end

      # Write a single Item into LookUpTable-Cache
      def lut_write_cache_item(name, lut_item, lut_data)
        status = Rails.cache.write("#{name}/#{lut_item}", lut_data)
        raise "Cache::write failed - Try lower :batch_size" unless status
      end



      # Delegating <attribute>_lut(args) method calls
      # HACK
      def method_missing(m, *args, &block)
        method_name = m.to_s
        if method_name.end_with?("_lut")
          lut_name = method_name[0..-5]
          self.lut(lut_name, args.first)
        else
          super(m, *args, &block)
        end
      end

  end
end

ActiveRecord::Base.send :include, LookUpTable

