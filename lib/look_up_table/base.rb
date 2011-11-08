require 'look_up_table'
require 'look_up_table/base'
require 'look_up_table/cache'
require 'look_up_table/method_missing'
require 'look_up_table/no_cache'
require 'look_up_table/support'

# CHECK: fail if Numbers as keys?
# TODO: Doc :look_up_table => options
module LookUpTable
  module ClassMethods

    # == Defining LookUpTables
    #
    #   # Sample class:
    #   Foobar(id: integer, foo: string, bar: integer)
    #
    # === Simplest way to define a LookUpTable:
    #   look_up_table :id
    #   look_up_table :foo
    #   look_up_table :bar
    #
    # === Add some options to your LookUpTable:
    #   look_up_table :foo, :batch_size => 5000, :where => "id > 10000"
    #
    # === Pass a block to define the LUT manually
    #   look_up_table :foo do |lut, foobar|
    #     lut[foobar.foo] = foobar.id
    #   end
    #
    # === Turn off AutoFinder and completly define the whole LUT yourself:
    #   look_up_table :foo, :sql_mode => false do |lut|
    #     Foobar.where("id > 10000").each do |foobar|
    #       lut[foobar.foo] = foobar.id
    #     end
    #   end
    def look_up_table(lut_key, options = {}, &block)
      options = {
        :batch_size     => 10000,
        :prefix         => "#{self.name}/",
        :read_on_init   => false,
        :use_cache      => true,
        :sql_mode       => true,
        :where          => nil
      }.merge(options)

      self.lut_set_proc(lut_key, block)
      self.lut_set_options(lut_key, options)

      self.lut(lut_key) if options[:read_on_init]
    end

    # == Calling LookUpTables
    #
    # === Call without any params
    # * Returns: All LUTs defined within Foobar
    #     Foobar.lut
    #     =>
    #       {
    #         :foo    => { :a => 1 },
    #         :bar    => { :b => 2 },
    #         :foobar => { :c => 3, :d => 4, :e => 5 }
    #       }
    #
    # === Call with :lut_key:
    # * Returns: Hash representing LUT defined by :lut_key
    #     Foobar.lut :foo
    #     => { :a => 1 }
    #
    # === Call with array of :lut_keys
    # * Returns: Hash representing LUT defined with :lut_key in given Array
    #     Foobar.lut [:foo, :bar]
    #     =>
    #       {
    #         :foo => { :a => 1 },
    #         :bar => { :b => 2 }
    #       }
    #
    # === Call with Call with :lut_key and :lut_item_key
    # * Returns: Value in LUT defined by :lut_key and :lut_item_key
    #     Foobar.lut :foo, "foobar"
    #     => 1
    #     # So we've got a Foobar with :foo => "foobar", its ID is '1'
    #
    # === Call with Call with :lut_key and :lut_item_key as Array
    # * Returns: Hash representing LUT defined by :lut_key with
    #   :lut_item_keys in Array
    #     Foobar.lut :foobar, ["foo", "bar", "oof"]
    #     =>
    #       {
    #         "foo" => 3,
    #         "bar" => 4,
    #         "oof" => nil
    #       }
    #     # So we got Foobars with ID '3' and '4'
    #     # and no Foobar defined by :foobar => :oof
    #
    # === Call with :lut_key as a Hash
    # * Returns: Hash representing LUTs given by keys of passed Hash.
    #   - If given value of Hash-Item is nil, will get whole LUT.
    #   - If given value is String or Symbol, will get value of LUT.
    #   - If given value is Array, will get values of entries.
    # * Example:
    #    Foobar.lut { :foo => :a, :bar => nil, :foobar => [:c, :d] }
    #    =>
    #      {
    #        :foo    => 1,
    #        :bar    => { :b => 2 },
    #        :foobar => { :c => 3, :d => 4 }
    #      }
    def lut(lut_key = nil, lut_item_key = nil)
      @lut ||= {}

      if lut_key.nil?
        hash = {}
        self.lut_keys.each { |key| hash[key] = self.lut(key) } # CHECK: use .inject?
        return hash
      end

      @lut[lut_key.intern] ||= lut_read(lut_key) || {} if lut_key.respond_to?(:intern)

      self.lut_deep_hash_call(:lut, @lut, lut_key, lut_item_key)
    end

    # Reset complete lut if name is omitted, resets given lut otherwise.
    # HACK: not cool do access and define @lut here
    def lut_reset(lut_key = nil)
      @lut ||= {}

      if lut_key
        @lut[lut_key.intern] = nil
        lut_write_cache_item(lut_key, 0, nil) unless lut_options[:skip_memcached] # CHECK: options call w/o name?
      else
        lut_keys.each { |k| lut_reset(k) }
        @lut = {}
      end
    end

    # Reading LUT and writing cache again
    def lut_reload(lut_key = nil)
      if lut_key
        lut_reset(lut_key)
        lut(lut_key)
      else
        lut_keys.each { |k| lut_reload(k) }
      end

      lut_keys
    end

    # Init complete LUT with all keys define.
    # But won't rewrite cache if allready written!
    # * Returns: Foobar.lut_keys
    #     Foobar.lut_init
    #     => [:id, :foo, :bar, :foobar]
    def lut_init(lut_key = nil)
      if lut_key
        lut(lut_key)
      else
        lut_keys.each { |k| lut_init(k) }
      end

      lut_keys
    end

    # Returns: Keys of LookUpTables defined
    #   Foobar.lut_keys
    #   => [:id, :foo, :bar, :foobar]
    def lut_keys
      lut_options.keys
    end

    # Returns: Options defined
    # * Accept same params as: Foobar.lut
    #     Foobar.lut_options :foobar
    #     =>
    #       {
    #         :batch_size=>10000,
    #         :prefix=>"Foobar/",
    #         :read_on_init=>false,
    #         :use_cache=>true,
    #         :sql_mode=>true,
    #         :where=>nil
    #       }
    def lut_options(lut_key = nil, option_key = nil)
      @lut_options ||= {}

      self.lut_deep_hash_call(:lut_options, @lut_options, lut_key, option_key)
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

