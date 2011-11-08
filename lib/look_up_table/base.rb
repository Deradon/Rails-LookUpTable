require 'look_up_table'
require 'look_up_table/base'
require 'look_up_table/cache'
require 'look_up_table/method_missing'
require 'look_up_table/no_cache'

module LookUpTable
  module ClassMethods
    # Defining a LookUpTable
    # TODO: Usage
    def look_up_table(lut_key, options = {}, &block)
      options = {
        :batch_size     => 10000,
        :prefix         => self.name,
        :read_on_init   => false,
        :use_cache      => true,
        :sql_mode       => true,
        :where          => nil
      }.merge(options)

      self.lut_set_proc(lut_key, block)
      self.lut_set_options(lut_key, options)

      self.lut(lut_key) if options[:read_on_init]
    end

    # Call to a LookUpTable.
    # * Example:
    #    * Tag.lut                          (Returns all LookUpTables)
    #    * Tag.lut :name                    (Returns LookUpTable given by :name)
    #    * Tag.lut(:name, "Berlin")         (Returns Value of LookUpTable named :name with :key "Berlin")
    #    * Tag.lut({:name => "Berlin", :title => "Berlin"})     TODO: returns hash
    # TODO: TestCases
    def lut(lut_key = nil, lut_item_key = nil)
      @lut ||= {}

      if lut_key.nil?
        hash = {}
        self.lut_keys.each { |key| hash[key] = self.lut(key) } # CHECK: use .inject?
        return hash
      end

      if (lut_key.respond_to?(:keys))
        hash = {}
        lut_key.each { |k,v| hash[k.intern] = self.lut(k,v) }
        return hash
      end

      lut = @lut[lut_key.to_sym] ||= lut_read(lut_key) || {}
      lut_item_key ? lut[lut_item_key] : lut
    end

    # Reset complete lut if name is omitted, resets given lut otherwise.
    # HACK: not cool do access and define @lut here
    def lut_reset(name = nil)
      @lut ||= {}

      if name
        @lut[name.to_sym] = nil
        lut_write_cache_item(name, 0, nil) unless lut_options[:skip_memcached] # CHECK: options call w/o name?
      else
        lut_keys.each { |k| lut_reset(k) }
        @lut = {}
      end
    end

    # Reading LUT and writing cache again
    def lut_reload(name = nil)
      if name
        lut_reset(name)
        lut(name)
      else
        lut_keys.each { |k| lut_reload(k) }
      end

      lut_keys
    end

    # Init complete LUT with all keys define.
    # But won't rewrite cache if allready written!
    def lut_init(name = nil)
      if name
        lut(name)
      else
        lut_keys.each { |k| lut_init(k) }
      end

      lut_keys
    end

    # Returns keys of LookUpTables defined
    def lut_keys
      lut_options.keys
    end

    # Usage
    # * Klass.lut_options
    # * Klass.lut_options(:lut_key)
    # * Klass.lut_options(:lut_key, :option_key)
    # * Klass.lut_options(:lut_key => :option_key)
    # * Klass.lut_options(:lut_key => [:option_key, :second_option_key])
    # TODO: test_cases
    # CHECK: some sweeter implementation?
    def lut_options(name = nil)#, option_key = nil)
      @lut_options ||= {}

#      if name && name.respond_to?(:keys)
#        if name[:lut_key] && name[:lut_key].respond_to?(:values)
#          return name[:lut_key].each.inject([]) do |arr, el|
#            arr << @lut_options[name.intern][el.intern]
#          end
#        elsif name[:lut_key]
#          return @lut_options[name.intern][option_key.intern]
#        else
#          return @lut_options[name.intern]
#        end
#      elsif name
#        (option_key) ? @lut_options[name.intern][option_key.intern] : @lut_options[name.intern]
#      else
#        return @lut_options
#      end

      (name) ? @lut_options[name.to_sym] : @lut_options
    end

    protected
      def lut_proc(lut_key = nil)
        @lut_proc ||= {}

        (lut_key) ? @lut_proc[lut_key.to_sym] : @lut_proc
      end

      # lut_set_proc(lut_name, block) / lut_proc(lut_name)
      def lut_set_proc(lut_key, block)
        lut_proc[lut_key.to_sym] = block
      end

      # lut_set_options(lut_name, options) / lut_options(lut_name)
      def lut_set_options(lut_key, options)
        lut_options[lut_key.to_sym] = options
      end

      # Reads a single lut
      def lut_read(name)
        return nil unless options = lut_options(name)# HACK

        if options[:use_cache]
          lut_read_from_cache(name)
        else
          lut_read_without_cache(name)
        end
      end
  end
end

