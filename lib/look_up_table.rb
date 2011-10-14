# TODO
# * add: lut_reset(:name)
module LookUpTable
  extend ActiveSupport::Concern

  # Class methods
  module ClassMethods
    # Defining a LookUpTable
    # TODO: Usage
    def look_up_table(lut_name, options={})
      options = {
        :batch_size     => 10000,
        :read_on_init   => true,
        :skip_memcached => false, #TODO
        :sql_mode       => true,
        :write_on_init  => true
      }.merge(options)

      if block_given?
        lut_write_to_cache(options[:batch_size], lut_name, options[:sql_mode], &Proc.new) if options[:write_on_init]
      else
        lut_write_to_cache(options[:batch_size], lut_name, options[:sql_mode]) if options[:write_on_init]
      end

      self.lut(lut_name) if options[:read_on_init]
    end

    # Write a LookUpTable into Cache
    # TODO refactor
    def lut_write_to_cache(batch_size, lut_name, sql_mode)
      if sql_mode
        if block_given?
          lut_write_to_cache_sql_mode(batch_size, lut_name, &Proc.new)
        else
          lut_write_to_cache_sql_mode(batch_size, lut_name)
        end
      else
        if block_given?
          lut_write_to_cache_no_sql_mode(batch_size, lut_name, &Proc.new)
        else
          lut_write_to_cache_no_sql_mode(batch_size, lut_name)
        end
      end
    end


    def lut_write_to_cache_sql_mode(batch_size, lut_name)
      batch_count = 0

      self.find_in_batches(:batch_size => batch_size) do |items|
        lut = {}
        items.each do |item|
          if block_given?
            yield(lut, item)
          else
            lut[item.send(lut_name)] = item.id
          end
        end

        self.lut_write_cache_item(lut_name, batch_count, lut)
        batch_count += 1
      end
    end


    def lut_write_to_cache_no_sql_mode(batch_size, lut_name)
      lut = {}
      batch_count = 0

      yield(lut)
      keys = lut.keys

      while
        key_block = keys.slice!(0,batch_size)
        break if key_block.empty?

        lut_block = {}
        key_block.each{|key| lut_block[key] = lut[key]}

        self.lut_write_cache_item(lut_name, batch_count, lut_block)
        batch_count += 1
      end
    end


    # Write a single Item into LookUpTable-Cache
    def lut_write_cache_item(lut_name, lut_item, lut_data)
      status = Rails.cache.write("#{lut_name}/#{lut_item}", lut_data)
      raise "Cache::write returned false" unless status
    end

    # Reads a single LookUpTable from Cache
    def lut_read_from_cache(lut_name)
      i   = 0
      lut = {}

      while res = lut_read_cache_item(lut_name, i)
        lut.merge!(res) if res
        i += 1
      end

      return lut
    end

    # Reads a single item of a LookUpTable from Cache
    def lut_read_cache_item(lut_name, lut_item)
      Rails.cache.read("#{lut_name}/#{lut_item}")
    end

    # Call to a LookUpTable, example Usage:
    # * Tag.lut(:name, "Berlin")
    # Returns nil or stored objects
    def lut(lut_name, search_by=nil)
      @@look_up_tables ||= {}
      @@look_up_tables[lut_name.to_sym] ||= lut_read_from_cache(lut_name) || {}

      return @@look_up_tables[lut_name.to_sym][search_by] if search_by
      return @@look_up_tables[lut_name.to_sym]
    end

    # Delegating <attribute>_lut(args) method calls
    def method_missing(m, *args, &block)
      method_name = m.to_s
      if method_name.end_with?("_lut")
        lut_name = method_name[0..-5]
        self.lut(lut_name, args.first)
      else
        raise "MethodNotFound: #{m}"
      end
    end

  end
end

ActiveRecord::Base.send :include, LookUpTable

